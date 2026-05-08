/**
 * ViteDriver
 *
 * Resolves entries from a Vite production manifest and renders the matching
 * tag set. In development (hot file present), it routes paths through the
 * Vite dev server URL and skips manifest reads entirely.
 *
 * Vite manifest shape (per file key):
 *   {
 *     "resources/js/app.js": {
 *       "file":    "assets/app-abc.js",
 *       "src":     "resources/js/app.js",
 *       "isEntry": true,
 *       "imports": [ "_vendor-def.js" ],   // keys into this same manifest
 *       "css":     [ "assets/app-abc.css" ]
 *     },
 *     "_vendor-def.js": { "file": "assets/vendor-def.js", "css": [ ... ] }
 *   }
 */
component extends="AbstractDriver" {

	/**
	 * Resolve a Vite entry to its real URL. In dev (hot file present) returns
	 * <devUrl>/<entry>; in prod returns the hashed file under buildPath.
	 *
	 * Throws EntryNotFound when the entry key is missing from the manifest.
	 *
	 * @entry   Vite source key (e.g. "resources/js/app.js").
	 * @options Reserved for future use; ignored by this driver.
	 */
	string function path( required string entry, struct options = {} ) {
		if ( isHot() ) {
			return devUrl() & "/" & reReplace( arguments.entry, "^/+", "" );
		}

		var key = "p|" & arguments.entry;
		if ( variables._paths.keyExists( key ) ) return variables._paths[ key ];

		var node = lookupEntry( arguments.entry );
		var built = joinPath( variables.settings.buildPath, node.file );
		variables._paths[ key ] = built;
		return built;
	}

	/**
	 * Render the full HTML tag set for a Vite entry. In dev mode emits a
	 * single dev-server <script type="module">; in prod emits CSS <link>s,
	 * <link rel="modulepreload"> for imported chunks, and the entry script.
	 *
	 * When `settings.criticalCss.enabled` is true and a critical CSS file
	 * exists for the current event (via `options.criticalEvent`), the CSS
	 * `<link rel="stylesheet">` block is replaced with an inline `<style>`
	 * + per-CSS preload+swap + `<noscript>` fallback. Modulepreload + entry
	 * <script> are unchanged. Critical handling is always skipped in dev
	 * (`isHot()==true`).
	 *
	 * @entry   Vite source key.
	 * @options { renderModulePreload, includeImportedCss, attributes,
	 *           criticalEvent, criticalSuppressInline, skipCritical, nonce }.
	 */
	string function tags( required string entry, struct options = {} ) {
		var attrs = arguments.options.keyExists( "attributes" ) ? arguments.options.attributes : {};

		// Dev mode: render dev-server entry tag (no caching — devCheckInterval governs hot file)
		if ( isHot() ) {
			return variables.renderer.viteDevTags(
				devUrl     = devUrl(),
				entry      = arguments.entry,
				attributes = attrs
			);
		}

		var renderPreload  = arguments.options.keyExists( "renderModulePreload" ) ? arguments.options.renderModulePreload : variables.settings.renderModulePreload;
		var includeCss     = arguments.options.keyExists( "includeImportedCss" )  ? arguments.options.includeImportedCss  : variables.settings.includeImportedCss;
		var skipCritical   = arguments.options.keyExists( "skipCritical" ) ? !!arguments.options.skipCritical : false;
		var suppressInline = arguments.options.keyExists( "criticalSuppressInline" ) ? !!arguments.options.criticalSuppressInline : false;
		var criticalEvent  = arguments.options.keyExists( "criticalEvent" ) ? arguments.options.criticalEvent : "";
		var nonce          = arguments.options.keyExists( "nonce" ) ? arguments.options.nonce : "";

		// Resolve inline critical first — its presence/absence is part of the cache key.
		var inlineCss = "";
		if ( !skipCritical ) {
			inlineCss = readCriticalCss( criticalEvent );
		}
		// Per-request dedupe: when the facade signals the inline has already
		// been rendered earlier this request, suppress the <style> here but
		// still preload-swap the CSS hrefs (so a second tags() call still
		// gets its full-CSS link).
		var emittedInline = ( len( inlineCss ) && !suppressInline );

		var cacheKey = arguments.entry & "|" & renderPreload & "|" & includeCss & "|" & attrsKey( attrs )
			& "|crit:" & ( len( inlineCss ) ? "1" : "0" )
			& "|skip:" & ( skipCritical ? "1" : "0" )
			& "|inline:" & ( emittedInline ? "1" : "0" )
			& "|evt:" & criticalEvent
			& "|nonce:" & nonce;

		if ( variables._tags.keyExists( cacheKey ) ) return variables._tags[ cacheKey ];

		var b = bundle(
			entry   = arguments.entry,
			options = { renderModulePreload: renderPreload, includeImportedCss: includeCss }
		);

		var html = "";
		if ( len( inlineCss ) ) {
			// Critical-CSS branch: inline <style> (when not suppressed) +
			// preload-swap CSS + modulepreload + entry script. When no
			// critical file exists for this event readCriticalCss() returns
			// "" and we fall through to the standard branch — preserving
			// byte-for-byte parity with non-critical apps.
			html = variables.renderer.viteCriticalProductionTags(
				inlineCss  = emittedInline ? inlineCss : "",
				bundle     = b,
				attributes = attrs,
				options    = { nonce: nonce }
			);
		} else {
			html = variables.renderer.viteProductionTags( bundle = b, attributes = attrs );
		}
		variables._tags[ cacheKey ] = html;
		return html;
	}

	/**
	 * Walk the manifest graph for an entry and collect:
	 *   - js:      the entry's compiled file
	 *   - css:     the entry's css plus css from any (recursively) imported chunks
	 *   - preload: imported chunk JS files (for <link rel="modulepreload">)
	 *
	 * @entry   Vite source key.
	 * @options { renderModulePreload, includeImportedCss }.
	 */
	struct function bundle( required string entry, struct options = {} ) {
		if ( isHot() ) {
			// In dev there is no graph; emit just the entry as JS.
			return {
				js: devUrl() & "/" & reReplace( arguments.entry, "^/+", "" ),
				css: [],
				preload: []
			};
		}

		var renderPreload = arguments.options.keyExists( "renderModulePreload" ) ? arguments.options.renderModulePreload : variables.settings.renderModulePreload;
		var includeCss    = arguments.options.keyExists( "includeImportedCss" )  ? arguments.options.includeImportedCss  : variables.settings.includeImportedCss;
		var cacheKey = "b|" & arguments.entry & "|" & renderPreload & "|" & includeCss;
		if ( variables._bundles.keyExists( cacheKey ) ) return variables._bundles[ cacheKey ];

		var manifest = getManifest();
		var node = lookupEntry( arguments.entry );

		// NOTE: Adobe CF passes arrays by value, so we wrap mutable collectors
		// in a struct (which is always by-reference) for cross-engine portability.
		var cssBag     = { out: [], seen: {} };
		var preloadBag = { out: [], seen: {} };

		// CSS belonging directly to the entry chunk (and recursively if includeCss)
		walkCss( node, manifest, cssBag, /*deep*/ includeCss );

		// modulepreload list from imported chunks
		if ( renderPreload ) {
			walkPreload( node, manifest, preloadBag );
		}

		var b = {
			js: joinPath( variables.settings.buildPath, node.file ),
			css: cssBag.out.map( ( f ) => joinPath( variables.settings.buildPath, f ) ),
			preload: preloadBag.out.map( ( f ) => joinPath( variables.settings.buildPath, f ) )
		};

		variables._bundles[ cacheKey ] = b;
		return b;
	}

	/**
	 * True when devMode is on and Vite's hot file is present.
	 */
	boolean function isHot() {
		return variables.watcher.isHot(
			hotFilePath      = absoluteHotPath(),
			devMode          = variables.settings.devMode,
			devCheckInterval = variables.settings.cache.devCheckInterval
		);
	}

	/**
	 * Render the @vite/client script tag in dev; empty string in prod.
	 */
	string function viteClient() {
		if ( !isHot() ) return "";
		return variables.renderer.viteClientTag( devUrl = devUrl() );
	}

	/* ------------------------------------------------------------------ */

	/**
	 * Look up an entry node in the parsed manifest.
	 *
	 * @entry Vite source key.
	 */
	private struct function lookupEntry( required string entry ) {
		var manifest = getManifest();
		if ( !manifest.keyExists( arguments.entry ) ) {
			throw(
				message = "Vite entry not found in manifest",
				type    = "EntryNotFound",
				detail  = "Looked for '#arguments.entry#' in #absoluteManifestPath()#"
			);
		}
		return manifest[ arguments.entry ];
	}

	/**
	 * Recursively collect CSS files from a manifest node and (optionally) any
	 * chunks it imports. Mutates the bag in place.
	 *
	 * @node     Current manifest entry being walked.
	 * @manifest The full parsed manifest (for following import keys).
	 * @bag      Mutable collector struct: { out: [], seen: {} }.
	 * @deep     When true, recurse into imports[]; when false, just the node's own css[].
	 */
	private function walkCss( required struct node, required struct manifest, required struct bag, required boolean deep ) {
		if ( arguments.node.keyExists( "css" ) && isArray( arguments.node.css ) ) {
			for ( var f in arguments.node.css ) {
				if ( !arguments.bag.seen.keyExists( f ) ) {
					arguments.bag.seen[ f ] = true;
					arguments.bag.out.append( f );
				}
			}
		}
		if ( !arguments.deep ) return;
		if ( arguments.node.keyExists( "imports" ) && isArray( arguments.node.imports ) ) {
			for ( var importKey in arguments.node.imports ) {
				var visitKey = "##imp:" & importKey;
				if ( arguments.bag.seen.keyExists( visitKey ) ) continue;
				arguments.bag.seen[ visitKey ] = true;
				if ( arguments.manifest.keyExists( importKey ) ) {
					walkCss( arguments.manifest[ importKey ], arguments.manifest, arguments.bag, true );
				}
			}
		}
	}

	/**
	 * Recursively collect imported chunk JS files for <link rel="modulepreload">.
	 * Mutates the bag in place.
	 *
	 * @node     Current manifest entry being walked.
	 * @manifest The full parsed manifest (for following import keys).
	 * @bag      Mutable collector struct: { out: [], seen: {} }.
	 */
	private function walkPreload( required struct node, required struct manifest, required struct bag ) {
		if ( !arguments.node.keyExists( "imports" ) || !isArray( arguments.node.imports ) ) return;
		for ( var importKey in arguments.node.imports ) {
			if ( arguments.bag.seen.keyExists( importKey ) ) continue;
			arguments.bag.seen[ importKey ] = true;
			if ( !arguments.manifest.keyExists( importKey ) ) continue;
			var child = arguments.manifest[ importKey ];
			if ( child.keyExists( "file" ) ) arguments.bag.out.append( child.file );
			walkPreload( child, arguments.manifest, arguments.bag );
		}
	}

	/**
	 * Resolve the Vite dev server base URL from the hot file (or fall back to
	 * settings.devServerUrl). Trailing slashes are stripped.
	 */
	private string function devUrl() {
		return variables.watcher.url(
			hotFilePath      = absoluteHotPath(),
			devMode          = variables.settings.devMode,
			devCheckInterval = variables.settings.cache.devCheckInterval,
			fallback         = variables.settings.devServerUrl
		);
	}

	/**
	 * Return the absolute (un-expanded) hot-file path. Pinned on first call so
	 * joinPath's regex doesn't run on every isHot()/url() check.
	 */
	private string function absoluteHotPath() {
		if ( !variables.keyExists( "_absHot" ) ) {
			variables._absHot = joinPath( variables.moduleRoot, variables.settings.hotFilePath );
		}
		return variables._absHot;
	}

	/**
	 * Stable key fragment for an attributes struct, used as part of the tag
	 * cache key. The serialized JSON is stable enough — hashing it adds work
	 * for no functional benefit, since struct keyExists is dictionary-fast.
	 *
	 * @s Attributes struct.
	 */
	private string function attrsKey( required struct s ) {
		if ( arguments.s.isEmpty() ) return "";
		return serializeJson( arguments.s );
	}

}
