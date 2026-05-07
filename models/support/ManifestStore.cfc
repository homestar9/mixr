/**
 * ManifestStore
 *
 * Owns parsed-manifest caching with double-checked locking.
 * - In production (devMode=false) a manifest is parsed once and pinned forever.
 * - In development the manifest mtime is rechecked at most once per
 *   devCheckInterval ms; 0 = check every request; -1 = never recheck.
 *
 * The store is intentionally not aware of Vite vs Mix manifest shape — it just
 * returns whatever deserialized JSON the manifest contains. Drivers interpret it.
 */
component singleton {

	// keyed by absolute (expanded) path
	variables._manifests = {};
	// keyed by absolute path -> { mtime: numeric, lastCheck: numeric }
	variables._meta = {};
	// reload listeners: keyed by absolute path -> array of callbacks
	variables._listeners = {};

	/**
	 * Constructor. Singleton; called once by WireBox at boot.
	 */
	ManifestStore function init() {
		return this;
	}

	/**
	 * Get the parsed manifest for the given path.
	 *
	 * @manifestPath relative or absolute (will be expanded)
	 * @devMode      whether to do mtime rechecks
	 * @devCheckInterval  ms throttle; 0=every request; -1=never
	 */
	struct function get(
		required string manifestPath,
		boolean devMode = false,
		numeric devCheckInterval = 2000
	) {
		var expanded = expandPath( cleanPath( arguments.manifestPath ) );

		// Cold path: not cached yet
		if ( !variables._manifests.keyExists( expanded ) ) {
			loadLocked( expanded );
			return variables._manifests[ expanded ];
		}

		// Hot path in production: lock-free struct read
		if ( !arguments.devMode || arguments.devCheckInterval == -1 ) {
			return variables._manifests[ expanded ];
		}

		// Dev mode: throttled mtime check
		var meta = variables._meta[ expanded ];
		var now = getTickCount();
		if ( arguments.devCheckInterval > 0 && ( now - meta.lastCheck ) < arguments.devCheckInterval ) {
			return variables._manifests[ expanded ];
		}

		// time to check mtime
		meta.lastCheck = now;
		if ( fileExists( expanded ) ) {
			var info = getFileInfo( expanded );
			var newMtime = info.lastModified.getTime();
			if ( newMtime != meta.mtime ) {
				loadLocked( expanded );
			}
		}

		return variables._manifests[ expanded ];
	}

	/**
	 * Register a callback fired whenever a given manifest is (re)loaded.
	 * Used by drivers to invalidate their downstream caches.
	 *
	 * @manifestPath Path to the manifest the listener cares about (relative or absolute).
	 * @callback     Function invoked with the parsed manifest struct on every load.
	 */
	function onReload( required string manifestPath, required any callback ) {
		var expanded = expandPath( cleanPath( arguments.manifestPath ) );
		if ( !variables._listeners.keyExists( expanded ) ) {
			variables._listeners[ expanded ] = [];
		}
		variables._listeners[ expanded ].append( arguments.callback );
	}

	/**
	 * Force a reload regardless of cache state. Used by Mixr.refresh()
	 * and tests.
	 *
	 * @manifestPath Specific manifest to reload; empty string reloads every cached manifest.
	 */
	function refresh( string manifestPath = "" ) {
		if ( len( arguments.manifestPath ) ) {
			var expanded = expandPath( cleanPath( arguments.manifestPath ) );
			loadLocked( expanded );
		} else {
			for ( var key in variables._manifests ) {
				loadLocked( key );
			}
		}
	}

	/* ------------------------------------------------------------------ */
	/*  internals                                                         */
	/* ------------------------------------------------------------------ */

	/**
	 * Parse and cache a manifest under an exclusive named lock to avoid races
	 * during cold-cache first reads. Fires any onReload listeners after the
	 * cache is consistent.
	 *
	 * @expanded Absolute (already expanded) path to the manifest file.
	 */
	private function loadLocked( required string expanded ) {
		lock name="mixr.manifest.#hash( arguments.expanded )#" type="exclusive" timeout="30" {
			var parsed = parseManifest( arguments.expanded );
			var mtime = fileExists( arguments.expanded )
				? getFileInfo( arguments.expanded ).lastModified.getTime()
				: 0;

			variables._manifests[ arguments.expanded ] = parsed;
			variables._meta[ arguments.expanded ] = { mtime: mtime, lastCheck: getTickCount() };

			// fire listeners after store is consistent
			if ( variables._listeners.keyExists( arguments.expanded ) ) {
				for ( var cb in variables._listeners[ arguments.expanded ] ) {
					cb( parsed );
				}
			}
		}
	}

	/**
	 * Read a manifest from disk and deserialize it.
	 * Throws ManifestNotFound when missing and MalformedManifest when the JSON
	 * is invalid or doesn't deserialize to a struct.
	 *
	 * @expanded Absolute (already expanded) path to the manifest file.
	 */
	private struct function parseManifest( required string expanded ) {
		if ( !fileExists( arguments.expanded ) ) {
			throw(
				message = "Manifest file not found",
				type    = "ManifestNotFound",
				detail  = "Checked #arguments.expanded#"
			);
		}

		var raw = fileRead( arguments.expanded );
		try {
			var data = deserializeJson( raw );
		} catch ( any e ) {
			throw(
				message = "Manifest JSON is malformed",
				type    = "MalformedManifest",
				detail  = "File: #arguments.expanded# — #e.message#"
			);
		}

		if ( !isStruct( data ) ) {
			throw(
				message = "Manifest JSON must deserialize to a struct/object",
				type    = "MalformedManifest",
				detail  = "File: #arguments.expanded#"
			);
		}

		return data;
	}

	/**
	 * Collapse runs of duplicate slashes in a path string to a single slash.
	 *
	 * @path Input path.
	 */
	private string function cleanPath( required string path ) {
		return reReplace( arguments.path, "/{2,}", "/", "all" );
	}

}
