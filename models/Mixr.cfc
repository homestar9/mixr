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
	 * @entry      Logical entry path.
	 * @moduleName Module to resolve from. Defaults to root app when omitted.
	 * @options    Optional struct: { as, attributes, renderModulePreload, includeImportedCss }.
	 */
	string function tags( required string entry, string moduleName = "", struct options = {} ) {
		return driverFor( arguments.moduleName ).tags( arguments.entry, arguments.options );
	}

	/**
	 * Return a normalized bundle struct ({ js, css[], preload[] }) for an entry.
	 * Use when you need to render tags yourself rather than use tags().
	 *
	 * @entry      Logical entry path.
	 * @moduleName Module to resolve from. Defaults to root app when omitted.
	 * @options    Optional struct: { renderModulePreload, includeImportedCss }.
	 */
	struct function bundle( required string entry, string moduleName = "", struct options = {} ) {
		return driverFor( arguments.moduleName ).bundle( arguments.entry, arguments.options );
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
		} else {
			variables._drivers = {};
			variables._scopes  = {};
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
	 * Two-tier cascade:
	 *
	 *   - **Behavioral keys** (driver, devMode, devServerUrl,
	 *     renderModulePreload, includeImportedCss, cache) inherit from the
	 *     root app's settings so the host can set one default and have it
	 *     apply to every submodule.
	 *
	 *   - **Module-relative paths** (manifestPath, buildPath, hotFilePath,
	 *     prependModuleRoot, prependPath) do NOT inherit from root. Each
	 *     module owns its own asset layout, so paths fall back to the
	 *     system defaults declared in mixr's ModuleConfig.cfc unless the
	 *     submodule (or moduleSettings.mixr.modules.<name>) explicitly
	 *     overrides them. This avoids the foot-gun where a host app's
	 *     `manifestPath` would otherwise be joined onto every submodule's
	 *     moduleRoot.
	 *
	 *   - **Submodule overrides** win over both of the above for any key
	 *     they explicitly declare.
	 *
	 * The 'modules' key itself is never inherited. Submodule settings are
	 * lazy-loaded the first time a moduleName is seen.
	 *
	 * @moduleName Module name; "" returns the root app's settings.
	 */
	private struct function effectiveSettings( required string moduleName ) {
		var rootBase = duplicate( settings );
		structDelete( rootBase, "modules" );

		// merge cache substruct defaults
		if ( !rootBase.keyExists( "cache" ) || !isStruct( rootBase.cache ) ) {
			rootBase.cache = { enabled: true, devCheckInterval: 2000 };
		} else {
			if ( !rootBase.cache.keyExists( "enabled" ) )          rootBase.cache.enabled = true;
			if ( !rootBase.cache.keyExists( "devCheckInterval" ) ) rootBase.cache.devCheckInterval = 2000;
		}

		// Root app: rootBase IS the effective settings.
		if ( !len( arguments.moduleName ) ) return rootBase;

		// Submodule: start from system path defaults, cascade behavioral
		// keys from root, then overlay any explicit submodule settings.
		var base = systemPathDefaults();

		var BEHAVIORAL_KEYS = [ "driver", "devMode", "devServerUrl", "renderModulePreload", "includeImportedCss" ];
		for ( var k in BEHAVIORAL_KEYS ) {
			if ( rootBase.keyExists( k ) ) base[ k ] = rootBase[ k ];
		}
		// cache is behavioral and always cascades
		base.cache = duplicate( rootBase.cache );

		// lazy-load the submodule's own ModuleConfig.cfc settings
		if ( !settings.modules.keyExists( arguments.moduleName ) ) {
			var moduleSettings = wirebox.getInstance( dsl = "coldbox:moduleSettings:#arguments.moduleName#" );
			settings.modules[ arguments.moduleName ] = moduleSettings.keyExists( "mixr" ) ? moduleSettings.mixr : {};
		}

		var override = settings.modules[ arguments.moduleName ];
		for ( var key in override ) {
			if ( key == "modules" ) continue;
			if ( key == "cache" && isStruct( override.cache ) ) {
				structAppend( base.cache, override.cache, true );
				continue;
			}
			base[ key ] = override[ key ];
		}

		return base;
	}

	/**
	 * System defaults for module-relative path settings. Kept in sync with
	 * the defaults declared in mixr's ModuleConfig.cfc. These are the values
	 * a submodule sees when neither it nor moduleSettings.mixr.modules.<name>
	 * declares an override — they are NOT inherited from the root app.
	 */
	private struct function systemPathDefaults() {
		return {
			"manifestPath"      : "/includes/build/.vite/manifest.json",
			"buildPath"         : "/includes/build",
			"hotFilePath"       : "/includes/hot",
			"prependModuleRoot" : true,
			"prependPath"       : "/includes"
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
