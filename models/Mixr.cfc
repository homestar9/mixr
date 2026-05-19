/**
 * Mixr 3.0
 *
 * Public facade. Resolves the appropriate driver for a given module (Vite,
 * flat manifest, or auto) and delegates path/tag rendering to it.
 *
 * Drivers are instantiated lazily and pinned per moduleName for the life of
 * the application — the only per-request work after warmup is a struct
 * lookup and a delegate call.
 */
component
	hint      = "Mixr facade — manifest + Vite asset helper"
	singleton
{

	property name="settings"   inject="coldbox:moduleSettings:mixr";
	property name="controller" inject="coldbox";
	property name="wirebox"    inject="wirebox";

	// drivers keyed by moduleName ("" for root)
	variables._drivers = {};
	// bound scopes keyed by moduleName
	variables._scopes  = {};
	// submodule's own settings (loaded lazily from its ModuleConfig.cfc)
	variables._submoduleOwnSettings = {};

	// support singletons (lazy)
	variables._store    = "";
	variables._watcher  = "";
	variables._renderer = "";

	/**
	 * Constructor. Mixr is a singleton; WireBox calls this once at boot.
	 */
	Mixr function init() {
		return this;
	}

	/* ------------------------------------------------------------------ */
	/*  Public API                                                        */
	/* ------------------------------------------------------------------ */

	/**
	 * Returns a module-bound scope for fluent calls: mixr().path(...) etc.
	 * Scopes are cached per moduleName, so repeated calls are O(1).
	 *
	 * @moduleName Name of the ColdBox module to bind the scope to. Use "" (default) for the root app.
	 */
	any function forModule( string moduleName = "" ) {
		var key = arguments.moduleName;
		if ( !variables._scopes.keyExists( key ) ) {
			variables._scopes[ key ] = wirebox.getInstance(
				name           = "MixrScope@mixr",
				initArguments  = { service: this, moduleName: key }
			);
		}
		return variables._scopes[ key ];
	}

	/**
	 * Resolve a single asset to its real, hashed URL.
	 *
	 * @entry      Logical entry path (Vite source key, e.g. "resources/js/app.js", or flat-manifest key like "/js/app.js").
	 * @moduleName Module to resolve from. Defaults to root app when omitted.
	 * @options    Driver-specific overrides (rarely used). See driver docs.
	 */
	string function path( required string entry, string moduleName = "", struct options = {} ) {
		return driverFor( arguments.moduleName ).path( arguments.entry, arguments.options );
	}

	/**
	 * Render the full HTML tag set for an entry: <link>/<script> for the manifest
	 * driver; <link rel="stylesheet">/<link rel="modulepreload">/<script type="module">
	 * for Vite (or a single dev-server <script> when hot).
	 *
	 * When `criticalCss.enabled` is true and a critical CSS file exists for
	 * the current event, the CSS portion is replaced with an inline `<style>`
	 * + preload-swap + `<noscript>` fallback. The current event is auto-
	 * detected from the RequestContext; pass `options.criticalEvent` to
	 * override or `options.skipCritical = true` to force standard output.
	 *
	 * Per-request dedupe: the inline `<style>` is emitted only on the first
	 * `tags()` call per moduleName per request. Subsequent calls in the same
	 * request still get their preload-swap link, but no duplicate `<style>`.
	 *
	 * @entry      Logical entry path.
	 * @moduleName Module to resolve from. Defaults to root app when omitted.
	 * @options    Optional struct: { as, attributes, renderModulePreload,
	 *             includeImportedCss, criticalEvent, criticalFile,
	 *             skipCritical, nonce }.
	 */
	string function tags( required string entry, string moduleName = "", struct options = {} ) {
		var opts = duplicate( arguments.options );

		// Inject the current event name when caller didn't override.
		if ( !opts.keyExists( "criticalEvent" ) ) {
			try {
				opts.criticalEvent = controller.getRequestService().getContext().getCurrentEvent();
			} catch ( any e ) {
				// Outside a request context (e.g. scheduled task) — leave unset
				// so drivers fall through to standard rendering.
				opts.criticalEvent = "";
			}
		}

		// Per-request dedupe of the inline <style>. First call sets the flag
		// and emits the inline; later calls signal the driver to suppress it
		// (the preload-swap CSS link is still emitted).
		try {
			var event = controller.getRequestService().getContext();
			var flag  = "mixr:criticalInlined:" & arguments.moduleName;
			if ( event.privateValueExists( flag ) ) {
				opts.criticalSuppressInline = true;
			} else {
				event.setPrivateValue( flag, true );
			}
		} catch ( any e ) {
			// Outside a request — caller is responsible for not double-rendering.
		}

		return driverFor( arguments.moduleName ).tags( arguments.entry, opts );
	}

	/**
	 * Render just the CSS half of what `tags()` would emit — stylesheet
	 * `<link>`s in the standard branch, or inline `<style>` + preload-swap
	 * `<link>`s when a critical-CSS file is present for the current event.
	 * Companion to `jsTags()`. In dev mode the Vite driver returns "" (CSS
	 * is injected via the entry script).
	 *
	 * Per-request dedupe: the first `cssTags()` (or `tags()`) call per
	 * moduleName per request sets the inline-rendered flag. Later calls in
	 * the same request still get their preload-swap link, but no duplicate
	 * inline `<style>`.
	 *
	 * @entry      Logical entry path.
	 * @moduleName Module to resolve from. Defaults to root app when omitted.
	 * @options    Optional struct: { as, attributes, renderModulePreload,
	 *             includeImportedCss, criticalEvent, skipCritical, nonce }.
	 */
	string function cssTags( required string entry, string moduleName = "", struct options = {} ) {
		var opts = duplicate( arguments.options );

		if ( !opts.keyExists( "criticalEvent" ) ) {
			try {
				opts.criticalEvent = controller.getRequestService().getContext().getCurrentEvent();
			} catch ( any e ) {
				opts.criticalEvent = "";
			}
		}

		try {
			var event = controller.getRequestService().getContext();
			var flag  = "mixr:criticalInlined:" & arguments.moduleName;
			if ( event.privateValueExists( flag ) ) {
				opts.criticalSuppressInline = true;
			} else {
				event.setPrivateValue( flag, true );
			}
		} catch ( any e ) {
			// outside a request — caller is responsible for not double-rendering.
		}

		return driverFor( arguments.moduleName ).cssTags( arguments.entry, opts );
	}

	/**
	 * Render just the JS half of what `tags()` would emit —
	 * `<link rel="modulepreload">` per imported chunk followed by the entry
	 * `<script type="module">`. In dev mode emits the single dev-server
	 * entry script. Companion to `cssTags()`.
	 *
	 * Does not interact with the critical-CSS dedupe flag.
	 *
	 * `cssTags( entry ) & jsTags( entry )` is byte-equivalent to `tags( entry )`
	 * (for matching options) — split for templates that want JS at the bottom
	 * of `<body>` and CSS in `<head>`.
	 *
	 * @entry      Logical entry path.
	 * @moduleName Module to resolve from. Defaults to root app when omitted.
	 * @options    Optional struct: { as, attributes, renderModulePreload,
	 *             includeImportedCss }.
	 */
	string function jsTags( required string entry, string moduleName = "", struct options = {} ) {
		return driverFor( arguments.moduleName ).jsTags( arguments.entry, arguments.options );
	}

	/**
	 * Return a normalized bundle struct ({ js, css[], preload[], criticalCss })
	 * for an entry. Use when you need to render tags yourself rather than use
	 * tags().
	 *
	 * The `criticalCss` field carries the inline CSS body for the current
	 * ColdBox event (or "" when disabled / in dev / file missing). The current
	 * event is auto-detected from the RequestContext; pass
	 * `options.criticalEvent` to override or `options.skipCritical = true` to
	 * force it empty. Reading the bundle does NOT set the per-request
	 * inline-dedupe flag — call `criticalCss( markRendered: true )` if you
	 * want a later `tags()` call to suppress its inline `<style>`.
	 *
	 * @entry      Logical entry path.
	 * @moduleName Module to resolve from. Defaults to root app when omitted.
	 * @options    Optional struct: { renderModulePreload, includeImportedCss,
	 *             criticalEvent, skipCritical }.
	 */
	struct function bundle( required string entry, string moduleName = "", struct options = {} ) {
		var opts = duplicate( arguments.options );

		// Inject the current event name when caller didn't override.
		if ( !opts.keyExists( "criticalEvent" ) ) {
			try {
				opts.criticalEvent = controller.getRequestService().getContext().getCurrentEvent();
			} catch ( any e ) {
				// Outside a request context (e.g. scheduled task) — leave unset
				// so drivers fall through to standard rendering.
				opts.criticalEvent = "";
			}
		}

		return driverFor( arguments.moduleName ).bundle( arguments.entry, opts );
	}

	/**
	 * Return the inline critical CSS body for the given (or current) event.
	 * Returns "" when `criticalCss.enabled` is false, when the driver is in
	 * dev mode, when no event can be resolved, or when the per-event file is
	 * missing. Use this when you want the inline content but are rendering
	 * your own tags (i.e. not calling `tags()`).
	 *
	 * Pure read by default — does NOT touch the per-request inline-dedupe
	 * flag. Pass `options.markRendered = true` to also set the flag, so a
	 * subsequent `tags()` call in the same request suppresses its inline
	 * `<style>`. The flag is only set when the returned string is non-empty.
	 *
	 * @eventName  ColdBox event name (e.g. "main.index"). Empty (default)
	 *             auto-detects from RequestContext.
	 * @moduleName Module whose driver should be queried. Defaults to root app.
	 * @options    Optional struct: { skipCritical, markRendered }. Note that
	 *             `criticalEvent` here is set by the eventName argument — pass
	 *             eventName positionally rather than via options.
	 */
	string function criticalCss(
		string eventName  = "",
		string moduleName = "",
		struct options    = {}
	) {
		var opts = duplicate( arguments.options );

		// eventName is the public-facing positional name; translate to the
		// internal driver-level key (criticalEvent) for symmetry with how
		// tags() and bundle() pass it through options. An explicit eventName
		// arg always wins; only fall back to auto-detect when both are empty.
		if ( len( arguments.eventName ) ) {
			opts.criticalEvent = arguments.eventName;
		} else if ( !opts.keyExists( "criticalEvent" ) ) {
			try {
				opts.criticalEvent = controller.getRequestService().getContext().getCurrentEvent();
			} catch ( any e ) {
				opts.criticalEvent = "";
			}
		}

		var inlineCss = driverFor( arguments.moduleName ).criticalCss( opts );

		// Opt-in dedupe: when caller plans to render the inline themselves,
		// they can mark the per-request flag so a later tags() call suppresses
		// its own inline. Only set the flag when there's actually something to
		// dedupe — empty strings shouldn't suppress anything.
		var markRendered = opts.keyExists( "markRendered" ) ? !!opts.markRendered : false;
		if ( markRendered && len( inlineCss ) ) {
			try {
				var event = controller.getRequestService().getContext();
				event.setPrivateValue( "mixr:criticalInlined:" & arguments.moduleName, true );
			} catch ( any e ) {
				// Outside a request — caller is responsible for not double-rendering.
			}
		}

		return inlineCss;
	}

	/**
	 * True when the active driver detects a Vite dev server (hot file present and devMode=true).
	 * Always false for the manifest driver.
	 *
	 * @moduleName Module whose driver should be queried. Defaults to root app.
	 */
	boolean function isHot( string moduleName = "" ) {
		return driverFor( arguments.moduleName ).isHot();
	}

	/**
	 * Renders <script type="module" src="…/@vite/client"></script>, but only
	 * once per request. Returns "" in production or after the first render.
	 * Per-request dedupe uses RequestContext private values; outside a request
	 * (e.g. scheduled tasks) the caller is responsible for not double-rendering.
	 *
	 * @moduleName Module whose driver should provide the dev URL. Defaults to root app.
	 */
	string function viteClient( string moduleName = "" ) {
		var driver = driverFor( arguments.moduleName );
		if ( !driver.isHot() ) return "";

		// per-request dedupe
		try {
			var event = controller.getRequestService().getContext();
			var flag  = "mixr:viteClientRendered:" & arguments.moduleName;
			if ( event.privateValueExists( flag ) ) return "";
			event.setPrivateValue( flag, true );
		} catch ( any e ) {
			// outside a request (scheduled task, etc.) — fall through; caller
			// is responsible for not double-rendering.
		}

		return driver.viteClient();
	}

	/**
	 * Backward-compatible 2.x method. Resolves a single asset path via the
	 * effective driver. Vite users should prefer path().
	 *
	 * @asset      Logical asset path (manifest key).
	 * @moduleName Module to resolve from. Defaults to root app when omitted.
	 */
	string function get( required string asset, string moduleName = "" ) {
		return path( arguments.asset, arguments.moduleName );
	}

	/**
	 * Drop all caches for one module (or all modules). Useful in tests and
	 * dev workflows that need to force a re-read after editing a manifest
	 * within the same app boot. Also resets the parsed-manifest store and
	 * the hot-file watcher.
	 *
	 * @moduleName Specific module to refresh. Empty string (default) refreshes everything.
	 */
	function refresh( string moduleName = "" ) {
		if ( len( arguments.moduleName ) ) {
			structDelete( variables._drivers, arguments.moduleName );
			structDelete( variables._scopes,  arguments.moduleName );
			structDelete( variables._submoduleOwnSettings, arguments.moduleName );
		} else {
			variables._drivers = {};
			variables._scopes  = {};
			variables._submoduleOwnSettings = {};
		}
		// also nuke parsed manifests + hot state so the next call hits disk
		getStore().refresh();
		getWatcher().refresh();
	}

	/* ------------------------------------------------------------------ */
	/*  Driver resolution                                                 */
	/* ------------------------------------------------------------------ */

	/**
	 * Resolve (and cache) the driver instance bound to a module. After the
	 * first call for a given moduleName, this is a struct lookup.
	 *
	 * @moduleName Module name; "" for the root app.
	 */
	private any function driverFor( required string moduleName ) {
		var key = arguments.moduleName;
		if ( variables._drivers.keyExists( key ) ) return variables._drivers[ key ];

		// Resolve effective settings + module root for this call site.
		var effective = effectiveSettings( arguments.moduleName );
		var moduleRoot = "";
		if ( len( arguments.moduleName ) ) {
			moduleRoot = controller.getRequestService().getContext().getModuleRoot( arguments.moduleName );
		}

		var driverName = resolveDriverName( effective, moduleRoot );
		var mapping = ( driverName == "vite" ) ? "ViteDriver@mixr" : "ManifestDriver@mixr";

		var driver = wirebox.getInstance(
			name          = mapping,
			initArguments = {
				settings:   effective,
				moduleRoot: moduleRoot,
				store:      getStore(),
				watcher:    getWatcher(),
				renderer:   getRenderer()
			}
		);

		variables._drivers[ key ] = driver;
		return driver;
	}

	/**
	 * Build the effective settings struct for one module.
	 *
	 * Each module is self-contained — there is no cascade from the root app
	 * to submodules. Settings resolve via a single chain (lowest to highest
	 * priority):
	 *
	 *   1. **System defaults** — declared in `systemDefaults()` below.
	 *   2. **Module's own settings** — for the root app, the values under
	 *      `moduleSettings.mixr.*`. For a submodule, the values declared in
	 *      its own `variables.settings.mixr.*` from its ModuleConfig.cfc.
	 *   3. **Host overrides** — `moduleSettings.mixr.modules.<name>.*` from
	 *      the root app's config. This is the ONLY mechanism by which one
	 *      module's config affects another.
	 *
	 * The 'modules' key itself is never inherited. Submodule own-settings are
	 * lazy-loaded the first time a moduleName is seen.
	 *
	 * Substruct values (`cache`, `criticalCss`) are merged key-by-key at each
	 * tier, not replaced wholesale — so a partial override like
	 * `{ criticalCss: { enabled: true } }` keeps default `path` and `suffix`.
	 *
	 * @moduleName Module name; "" returns the root app's settings.
	 */
	private struct function effectiveSettings( required string moduleName ) {
		// Root app: tier 2 IS the answer (its own settings, with defaults filled in).
		if ( !len( arguments.moduleName ) ) {
			return mergeWithDefaults( duplicate( settings ) );
		}

		// Submodule: defaults → own settings → host override.
		var base = mergeWithDefaults( {} );
		mergeInto( base, lazyLoadSubmoduleOwnSettings( arguments.moduleName ) );
		if ( settings.keyExists( "modules" ) && settings.modules.keyExists( arguments.moduleName ) ) {
			mergeInto( base, settings.modules[ arguments.moduleName ] );
		}
		return base;
	}

	/**
	 * Read a submodule's own mixr settings (from its ModuleConfig.cfc),
	 * cached per-moduleName for the life of the application. Returns an
	 * empty struct if the submodule does not declare a `mixr` settings key.
	 *
	 * @moduleName Submodule name (non-empty).
	 */
	private struct function lazyLoadSubmoduleOwnSettings( required string moduleName ) {
		if ( variables._submoduleOwnSettings.keyExists( arguments.moduleName ) ) {
			return variables._submoduleOwnSettings[ arguments.moduleName ];
		}
		var moduleSettings = wirebox.getInstance( dsl = "coldbox:moduleSettings:#arguments.moduleName#" );
		var own = ( moduleSettings.keyExists( "mixr" ) && isStruct( moduleSettings.mixr ) ) ? moduleSettings.mixr : {};
		variables._submoduleOwnSettings[ arguments.moduleName ] = own;
		return own;
	}

	/**
	 * Merge `overrides` over Mixr's system defaults and return a new struct.
	 * Substructs (`cache`, `criticalCss`) are merged key-by-key, not replaced
	 * wholesale. The `modules` key is stripped — it is a top-level routing
	 * concept, not part of any module's effective settings.
	 *
	 * @overrides Partial settings struct from the user's config.
	 */
	private struct function mergeWithDefaults( required struct overrides ) {
		var base = systemDefaults();
		mergeInto( base, arguments.overrides );
		structDelete( base, "modules" );
		return base;
	}

	/**
	 * Merge `overrides` into `base` in place. Top-level keys are replaced;
	 * substructs are merged key-by-key (one level deep) so partial overrides
	 * preserve defaults for keys they do not specify.
	 *
	 * @base      Target struct (mutated in place).
	 * @overrides Source struct.
	 */
	private function mergeInto( required struct base, required struct overrides ) {
		for ( var key in arguments.overrides ) {
			if ( key == "modules" ) continue;
			var v = arguments.overrides[ key ];
			if ( isStruct( v ) && arguments.base.keyExists( key ) && isStruct( arguments.base[ key ] ) ) {
				structAppend( arguments.base[ key ], v, true );
			} else {
				arguments.base[ key ] = v;
			}
		}
	}

	/**
	 * Mixr's system defaults — the canonical source of truth for every
	 * setting key. Each module (root app or submodule) starts from these
	 * values before its own settings (and any host overrides) are layered
	 * on. `ModuleConfig.cfc` intentionally ships an empty `variables.settings`
	 * so this method remains the single place defaults are declared.
	 */
	private struct function systemDefaults() {
		return {
			"driver"              : "auto",
			"manifestPath"        : "/includes/build/.vite/manifest.json",
			"buildPath"           : "/includes/build",
			"hotFilePath"         : "/includes/hot",
			"devServerUrl"        : "",
			"devMode"             : false,
			"renderModulePreload" : true,
			"includeImportedCss"  : true,
			"prependModuleRoot"   : true,
			"prependPath"         : "/includes",
			"cache"               : {
				"enabled"          : true,
				"devCheckInterval" : 2000
			},
			"criticalCss"         : {
				"enabled" : false,
				"path"    : "/includes/critical",
				"suffix"  : ".critical.css"
			}
		};
	}

	/**
	 * Pick which driver class to use for a (settings, moduleRoot) pair:
	 *   "vite"     -> ViteDriver
	 *   "manifest" -> ManifestDriver
	 *   "auto"     -> Vite if hot file present OR manifest looks like Vite shape; else manifest
	 *
	 * @settings   Effective settings struct for the module.
	 * @moduleRoot Filesystem-relative module root, used to resolve hot/manifest paths.
	 */
	private string function resolveDriverName( required struct settings, required string moduleRoot ) {
		var declared = lcase( arguments.settings.keyExists( "driver" ) ? arguments.settings.driver : "auto" );
		if ( declared == "vite" || declared == "manifest" ) return declared;
		if ( declared != "auto" ) {
			throw(
				message = "Unknown Mixr driver '#declared#'",
				type    = "InvalidDriver",
				detail  = "Expected one of: vite, manifest, auto"
			);
		}

		// Auto: hot file beats everything
		var hotKey = arguments.settings.keyExists( "hotFilePath" ) ? arguments.settings.hotFilePath : "/includes/hot";
		var hotPath = expandPath( joinPath( arguments.moduleRoot, hotKey ) );
		if ( fileExists( hotPath ) ) return "vite";

		// Otherwise sniff the manifest
		var manifestAbs = expandPath( joinPath( arguments.moduleRoot, arguments.settings.manifestPath ) );
		if ( !fileExists( manifestAbs ) ) {
			throw(
				message = "Mixr could not auto-detect driver: no manifest found",
				type    = "ManifestNotFound",
				detail  = "Checked #manifestAbs#. Set 'driver' explicitly or provide a manifest."
			);
		}
		try {
			var sample = deserializeJson( fileRead( manifestAbs ) );
		} catch ( any e ) {
			throw(
				message = "Manifest JSON is malformed",
				type    = "MalformedManifest",
				detail  = manifestAbs & " — " & e.message
			);
		}
		// Vite manifests have struct values with a 'file' key
		for ( var k in sample ) {
			if ( isStruct( sample[ k ] ) && sample[ k ].keyExists( "file" ) ) return "vite";
			break;
		}
		return "manifest";
	}

	/* ------------------------------------------------------------------ */
	/*  collaborators                                                     */
	/* ------------------------------------------------------------------ */

	/**
	 * Lazy-resolve the singleton ManifestStore.
	 */
	private any function getStore() {
		if ( isSimpleValue( variables._store ) ) variables._store = wirebox.getInstance( "ManifestStore@mixr" );
		return variables._store;
	}

	/**
	 * Lazy-resolve the singleton HotFileWatcher.
	 */
	private any function getWatcher() {
		if ( isSimpleValue( variables._watcher ) ) variables._watcher = wirebox.getInstance( "HotFileWatcher@mixr" );
		return variables._watcher;
	}

	/**
	 * Lazy-resolve the singleton TagRenderer.
	 */
	private any function getRenderer() {
		if ( isSimpleValue( variables._renderer ) ) variables._renderer = wirebox.getInstance( "TagRenderer@mixr" );
		return variables._renderer;
	}

	/**
	 * Join two path segments with a single slash, collapse duplicates, and
	 * ensure a leading slash.
	 *
	 * @base Leading path segment (may be empty).
	 * @sub  Trailing path segment.
	 */
	private string function joinPath( required string base, required string sub ) {
		var combined = arguments.base & "/" & arguments.sub;
		combined = reReplace( combined, "/{2,}", "/", "all" );
		if ( !combined.startsWith( "/" ) ) combined = "/" & combined;
		return combined;
	}

}
