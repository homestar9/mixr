/**
 * AbstractDriver
 *
 * Holds shared state every driver instance keeps: settings, moduleRoot,
 * support collaborators, and per-driver caches that get cleared whenever the
 * underlying manifest is reloaded.
 *
 * Each driver instance is bound to one (moduleName, settings) tuple and is
 * cached by Mixr.cfc for the life of the application.
 */
component {

	property name="settings"   type="struct";
	property name="moduleRoot" type="string";
	property name="store"      type="any";
	property name="watcher"    type="any";
	property name="renderer"   type="any";

	// keyed caches — invalidated by clearCaches()
	variables._paths    = {};
	variables._bundles  = {};
	variables._tags     = {};
	// per-event inline critical CSS contents:
	//   variables._criticalCache[ eventName ] = { contents, mtime, lastChecked }
	variables._criticalCache = {};

	/**
	 * Constructor. Wires the driver to its settings, module root, and shared
	 * collaborators, and registers a manifest-reload listener so derived
	 * caches are invalidated whenever the underlying manifest is reparsed.
	 *
	 * @settings   Effective settings struct (already cascaded by Mixr).
	 * @moduleRoot Filesystem-relative module root used to resolve manifest/hot paths.
	 * @store      Singleton ManifestStore for parsed-manifest caching.
	 * @watcher    Singleton HotFileWatcher for dev-server detection.
	 * @renderer   Singleton TagRenderer for HTML serialization.
	 */
	function init(
		required struct settings,
		required string moduleRoot,
		required any store,
		required any watcher,
		required any renderer
	) {
		variables.settings   = arguments.settings;
		variables.moduleRoot = arguments.moduleRoot;
		variables.store      = arguments.store;
		variables.watcher    = arguments.watcher;
		variables.renderer   = arguments.renderer;

		// Pin the absolute (un-expanded) manifest path once. joinPath runs a
		// regex on every call, so caching the result keeps it off the hot path.
		variables._absManifest = joinPath( variables.moduleRoot, variables.settings.manifestPath );

		// any time the manifest reloads, drop our derived caches
		variables.store.onReload(
			manifestPath = variables._absManifest,
			callback     = ( parsed ) => clearCaches()
		);

		return this;
	}

	/**
	 * Empty all per-driver derived caches (resolved paths, bundles, tag HTML).
	 * Called by the ManifestStore reload listener and by Mixr.refresh().
	 */
	function clearCaches() {
		variables._paths         = {};
		variables._bundles       = {};
		variables._tags          = {};
		variables._criticalCache = {};
	}

	/* ------------------------------------------------------------------ */

	/**
	 * Get the parsed manifest for this driver, going through the shared store
	 * (which handles caching and dev-mode mtime rechecks).
	 */
	struct function getManifest() {
		return variables.store.get(
			manifestPath     = variables._absManifest,
			devMode          = variables.settings.devMode,
			devCheckInterval = variables.settings.cache.devCheckInterval
		);
	}

	/**
	 * Return the cached absolute (un-expanded) manifest path.
	 */
	string function absoluteManifestPath() {
		return variables._absManifest;
	}

	/**
	 * Public option-aware accessor for the inline critical CSS body. Honors the
	 * same `skipCritical` and `criticalEvent` options that `tags()` and
	 * `bundle()` accept, so the facade can hand options through uniformly.
	 *
	 * Returns "" when `skipCritical` is true; otherwise delegates to
	 * `readCriticalCss( criticalEvent )` (which returns "" when disabled, in
	 * dev, when the event is empty, or when the file is missing).
	 *
	 * @options { criticalEvent, skipCritical }.
	 */
	string function criticalCss( struct options = {} ) {
		var skipCritical  = arguments.options.keyExists( "skipCritical" ) ? !!arguments.options.skipCritical : false;
		if ( skipCritical ) return "";
		var criticalEvent = arguments.options.keyExists( "criticalEvent" ) ? arguments.options.criticalEvent : "";
		return readCriticalCss( criticalEvent );
	}

	/**
	 * Read and cache the inline critical CSS contents for a given event.
	 *
	 * Returns an empty string when:
	 *   - settings.criticalCss.enabled is false, or
	 *   - isHot() is true (critical CSS is unconditionally skipped in dev), or
	 *   - eventName is empty (no event in context, e.g. scheduled task), or
	 *   - the resolved file does not exist, or
	 *   - the file read fails (e.g. mid-write race during a build).
	 *
	 * In production, file contents are read once and pinned. In dev, mtime
	 * checks are throttled by `settings.cache.devCheckInterval` (same
	 * semantics as ManifestStore: 0=every request, N=throttle ms, -1=never).
	 *
	 * Throws `MalformedCriticalCss` if the file body contains the literal
	 * string `</style>` — that would break HTML structure when inlined.
	 *
	 * @eventName ColdBox event name (e.g. "main.index"). Empty string returns "".
	 */
	string function readCriticalCss( required string eventName ) {
		if ( !variables.settings.keyExists( "criticalCss" ) ) return "";
		if ( !variables.settings.criticalCss.enabled )       return "";
		if ( !len( arguments.eventName ) )                   return "";
		if ( isHot() )                                       return "";

		var cached = variables._criticalCache.keyExists( arguments.eventName )
			? variables._criticalCache[ arguments.eventName ]
			: { contents: "", mtime: 0, lastChecked: 0, resolved: false };

		var devCheck = variables.settings.cache.devCheckInterval;
		var inDevCheckMode = variables.settings.devMode && devCheck != -1;

		if ( cached.resolved && !inDevCheckMode ) {
			return cached.contents;
		}

		// In dev: throttle mtime rechecks
		if ( cached.resolved && inDevCheckMode && devCheck > 0 ) {
			var nowMs = getTickCount();
			if ( ( nowMs - cached.lastChecked ) < devCheck ) {
				return cached.contents;
			}
		}

		var absPath = expandPath( joinPath(
			joinPath( variables.moduleRoot, variables.settings.criticalCss.path ),
			arguments.eventName & variables.settings.criticalCss.suffix
		) );

		if ( !fileExists( absPath ) ) {
			variables._criticalCache[ arguments.eventName ] = {
				contents    : "",
				mtime       : 0,
				lastChecked : getTickCount(),
				resolved    : true
			};
			return "";
		}

		var currentMtime = getFileInfo( absPath ).lastModified.getTime();
		if ( cached.resolved && cached.mtime == currentMtime ) {
			cached.lastChecked = getTickCount();
			variables._criticalCache[ arguments.eventName ] = cached;
			return cached.contents;
		}

		var contents = "";
		try {
			contents = fileRead( absPath );
		} catch ( any e ) {
			// transient read failure (file mid-write, etc.) — fall through silently
			return "";
		}

		// XSS / HTML-structure guard: a critical CSS file containing </style>
		// would break the inlined <style> block. Reject loudly so the broken
		// build artifact is fixed at the source.
		if ( reFindNoCase( "</style", contents ) ) {
			throw(
				message = "Critical CSS file contains literal </style> sequence",
				type    = "MalformedCriticalCss",
				detail  = "Refusing to inline " & absPath & " — it would break HTML structure. Fix the source build artifact."
			);
		}

		variables._criticalCache[ arguments.eventName ] = {
			contents    : contents,
			mtime       : currentMtime,
			lastChecked : getTickCount(),
			resolved    : true
		};
		return contents;
	}

	/**
	 * Each concrete driver must implement isHot() — true when devMode is on
	 * AND a Vite hot file is present. ManifestDriver always returns false.
	 */
	boolean function isHot() {
		return false;
	}

	/**
	 * Join a module root with a sub-path, collapsing duplicate slashes and
	 * always returning a single leading slash.
	 *
	 * @base Leading path segment (may be empty).
	 * @sub  Trailing path segment.
	 */
	string function joinPath( required string base, required string sub ) {
		var combined = arguments.base & "/" & arguments.sub;
		combined = reReplace( combined, "/{2,}", "/", "all" );
		if ( !combined.startsWith( "/" ) ) combined = "/" & combined;
		return combined;
	}

}
