/**
 * HotFileWatcher
 *
 * Tracks Vite's "hot" file (typically /includes/hot) which contains the dev
 * server URL while `vite dev` is running.
 *
 * In production (devMode=false), `isHot()` returns false without ever touching
 * the disk. In development, presence is checked at most once per
 * devCheckInterval ms. devCheckInterval semantics match ManifestStore.
 */
component singleton {

	// keyed by absolute path -> { hot: boolean, url: string, lastCheck: numeric }
	variables._state = {};

	/**
	 * Constructor. Singleton; called once by WireBox at boot.
	 */
	HotFileWatcher function init() {
		return this;
	}

	/**
	 * True when the Vite hot file is present (and devMode is on).
	 *
	 * @hotFilePath      Path to Vite's hot file (relative or absolute).
	 * @devMode          When false, returns false without touching the disk.
	 * @devCheckInterval Throttle for hot-file rechecks: 0=every call, N ms=throttle, -1=never recheck.
	 */
	boolean function isHot(
		required string hotFilePath,
		boolean devMode = false,
		numeric devCheckInterval = 2000
	) {
		if ( !arguments.devMode ) {
			return false;
		}
		return getState( argumentCollection = arguments ).hot;
	}

	/**
	 * Returns the dev server base URL from the hot file, or empty string when
	 * not hot. URL has no trailing slash.
	 *
	 * @hotFilePath      Path to Vite's hot file (relative or absolute).
	 * @devMode          When false, returns "" without touching the disk.
	 * @devCheckInterval Throttle for hot-file rechecks (see isHot()).
	 * @fallback         URL to use when the hot file is present but empty.
	 */
	string function url(
		required string hotFilePath,
		boolean devMode = false,
		numeric devCheckInterval = 2000,
		string fallback = ""
	) {
		if ( !arguments.devMode ) {
			return "";
		}
		var s = getState( argumentCollection = arguments );
		if ( !s.hot ) return "";
		return len( s.devUrl ) ? s.devUrl : arguments.fallback;
	}

	/**
	 * Forget cached hot-file state. Used by Mixr.refresh() and tests.
	 *
	 * @hotFilePath Specific path to forget; empty string clears all entries.
	 */
	function refresh( string hotFilePath = "" ) {
		if ( len( arguments.hotFilePath ) ) {
			var expanded = expandPath( arguments.hotFilePath );
			structDelete( variables._state, expanded );
		} else {
			variables._state = {};
		}
	}

	/* ------------------------------------------------------------------ */

	/**
	 * Read (or recheck) the hot-file state for a given path. Honors
	 * devCheckInterval throttling.
	 *
	 * @hotFilePath      Path to Vite's hot file.
	 * @devMode          Forwarded from isHot()/url(); not used here directly.
	 * @devCheckInterval Throttle window in ms; 0=every call, -1=never recheck.
	 */
	private struct function getState(
		required string hotFilePath,
		required boolean devMode,
		required numeric devCheckInterval
	) {
		var expanded = expandPath( arguments.hotFilePath );
		var now = getTickCount();

		if ( variables._state.keyExists( expanded ) ) {
			var s = variables._state[ expanded ];
			// devCheckInterval semantics:
			//   -1 => never recheck after first read
			//    0 => recheck every call
			//   N  => recheck if stale
			if ( arguments.devCheckInterval == -1 ) return s;
			if ( arguments.devCheckInterval > 0 && ( now - s.lastCheck ) < arguments.devCheckInterval ) {
				return s;
			}
		}

		var present = fileExists( expanded );
		var devUrl = "";
		if ( present ) {
			devUrl = trim( fileRead( expanded ) );
			// strip trailing slash for predictable concat
			devUrl = reReplace( devUrl, "/+$", "" );
		}

		var state = { hot: present, devUrl: devUrl, lastCheck: now };
		variables._state[ expanded ] = state;
		return state;
	}

}
