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
	variables._paths   = {};
	variables._bundles = {};
	variables._tags    = {};

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

		// any time the manifest reloads, drop our derived caches
		variables.store.onReload(
			manifestPath = absoluteManifestPath(),
			callback     = ( parsed ) => clearCaches()
		);

		return this;
	}

	/**
	 * Empty all per-driver derived caches (resolved paths, bundles, tag HTML).
	 * Called by the ManifestStore reload listener and by Mixr.refresh().
	 */
	function clearCaches() {
		variables._paths   = {};
		variables._bundles = {};
		variables._tags    = {};
	}

	/* ------------------------------------------------------------------ */

	/**
	 * Get the parsed manifest for this driver, going through the shared store
	 * (which handles caching and dev-mode mtime rechecks).
	 */
	struct function getManifest() {
		return variables.store.get(
			manifestPath     = absoluteManifestPath(),
			devMode          = variables.settings.devMode,
			devCheckInterval = variables.settings.cache.devCheckInterval
		);
	}

	/**
	 * Compute the absolute (un-expanded) manifest path by joining moduleRoot
	 * and settings.manifestPath.
	 */
	string function absoluteManifestPath() {
		return joinPath( variables.moduleRoot, variables.settings.manifestPath );
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
