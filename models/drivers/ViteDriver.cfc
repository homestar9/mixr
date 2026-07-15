/**
 * ViteDriver
 *
 * Resolves entries from a Vite production manifest and renders the matching
 * tag set. In development (hot file present), it routes paths through the
 * Vite dev server URL and skips manifest reads entirely.
 *
 * Vite manifest shape (per file key). The schema of `.vite/manifest.json` is
 * stable across Vite 5 through 8 — Vite 8's Rolldown/Oxc/Lightning CSS changes
 * are build-engine internals and do not alter manifest output:
 *   {
 *     "resources/js/app.js": {
 *       "file":           "assets/app-abc.js",
 *       "name":           "app",
 *       "src":            "resources/js/app.js",
 *       "isEntry":        true,
 *       "imports":        [ "_vendor-def.js" ],   // keys into this same manifest
 *       "dynamicImports": [ "_lazy-ghi.js" ],      // lazy chunks — NOT walked here
 *       "css":            [ "assets/app-abc.css" ]
 *     },
 *     "_vendor-def.js": { "file": "assets/vendor-def.js", "css": [ ... ] }
 *   }
 *
 * This driver reads only `file`, `css`, and `imports`. Every other field
 * (`name`, `src`, `isEntry`, `isDynamicEntry`, `dynamicImports`, `assets`,
 * `integrity`, …) is ignored — which is why newer Vite versions are
 * non-breaking. Dynamically-imported chunks are intentionally excluded from
 * the eager css[]/modulepreload graph.
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
		var built = assetUrl( node.file );
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
	 * Render just the CSS slice of a Vite bundle: stylesheet `<link>`s in the
	 * standard branch, or inline `<style>` + preload-swap `<link>`s when a
	 * critical-CSS file is present for the current event. Returns "" in dev
	 * (Vite injects CSS via the entry script).
	 *
	 * Concatenating `cssTags( entry, opts )` with `jsTags( entry, opts )` is
	 * byte-equivalent to `tags( entry, opts )` in production for the same opts.
	 *
	 * @entry   Vite source key.
	 * @options { includeImportedCss, criticalEvent, criticalSuppressInline,
	 *           skipCritical, nonce, attributes }. Note: `attributes` here is
	 *           applied to plain stylesheet `<link>` tags, NOT the entry script.
	 */
	string function cssTags( required string entry, struct options = {} ) {
		// In dev, Vite injects CSS via the entry script — nothing to emit in <head>.
		if ( isHot() ) return "";

		var attrs          = arguments.options.keyExists( "attributes" ) ? arguments.options.attributes : {};
		var includeCss     = arguments.options.keyExists( "includeImportedCss" )  ? arguments.options.includeImportedCss  : variables.settings.includeImportedCss;
		var skipCritical   = arguments.options.keyExists( "skipCritical" ) ? !!arguments.options.skipCritical : false;
		var suppressInline = arguments.options.keyExists( "criticalSuppressInline" ) ? !!arguments.options.criticalSuppressInline : false;
		var criticalEvent  = arguments.options.keyExists( "criticalEvent" ) ? arguments.options.criticalEvent : "";
		var nonce          = arguments.options.keyExists( "nonce" ) ? arguments.options.nonce : "";

		var inlineCss     = skipCritical ? "" : readCriticalCss( criticalEvent );
		var emittedInline = ( len( inlineCss ) && !suppressInline );

		// renderModulePreload doesn't affect CSS output but it's part of bundle()'s
		// cache key — match the tags() branch by always reading the same shape.
		var b = bundle(
			entry   = arguments.entry,
			options = {
				renderModulePreload: arguments.options.keyExists( "renderModulePreload" ) ? arguments.options.renderModulePreload : variables.settings.renderModulePreload,
				includeImportedCss:  includeCss
			}
		);

		return variables.renderer.viteCssTags(
			inlineCss  = emittedInline ? inlineCss : "",
			bundle     = b,
			attributes = attrs,
			options    = { nonce: nonce, criticalMode: len( inlineCss ) > 0 }
		);
	}

	/**
	 * Render just the JS slice of a Vite bundle: `<link rel="modulepreload">`
	 * for each imported chunk followed by the entry `<script type="module">`.
	 * In dev (hot file present), returns the single dev-server entry script.
	 *
	 * Concatenating `cssTags( entry, opts )` with `jsTags( entry, opts )` is
	 * byte-equivalent to `tags( entry, opts )` in production for the same opts.
	 *
	 * @entry   Vite source key.
	 * @options { renderModulePreload, includeImportedCss, attributes }.
	 */
	string function jsTags( required string entry, struct options = {} ) {
		var attrs = arguments.options.keyExists( "attributes" ) ? arguments.options.attributes : {};

		if ( isHot() ) {
			return variables.renderer.viteDevTags(
				devUrl     = devUrl(),
				entry      = arguments.entry,
				attributes = attrs
			);
		}

		var renderPreload = arguments.options.keyExists( "renderModulePreload" ) ? arguments.options.renderModulePreload : variables.settings.renderModulePreload;
		var includeCss    = arguments.options.keyExists( "includeImportedCss" )  ? arguments.options.includeImportedCss  : variables.settings.includeImportedCss;

		var b = bundle(
			entry   = arguments.entry,
			options = { renderModulePreload: renderPreload, includeImportedCss: includeCss }
		);

		return variables.renderer.viteJsTags( bundle = b, attributes = attrs );
	}

	/**
	 * Walk the manifest graph for an entry and collect:
	 *   - js:          the entry's compiled file
	 *   - css:         the entry's css plus css from any (recursively) imported chunks
	 *   - preload:     imported chunk JS files (for <link rel="modulepreload">)
	 *   - criticalCss: inline CSS body for the current event (or "" — see below)
	 *
	 * The `criticalCss` field obeys the same rules as `readCriticalCss()`:
	 * empty when `criticalCss.enabled` is false, in dev, when no event is
	 * provided, or when the per-event file is missing. It is **not** stored in
	 * `_bundles` — manifest-derived parts cache as before, but `criticalCss` is
	 * read fresh on each call (already mtime-throttled inside the driver's
	 * `_criticalCache`). Use `options.markRendered` only via the facade's
	 * `criticalCss()` method — bundle is a pure data shape.
	 *
	 * @entry   Vite source key.
	 * @options { renderModulePreload, includeImportedCss, criticalEvent, skipCritical }.
	 */
	struct function bundle( required string entry, struct options = {} ) {
		var skipCritical  = arguments.options.keyExists( "skipCritical" ) ? !!arguments.options.skipCritical : false;
		var criticalEvent = arguments.options.keyExists( "criticalEvent" ) ? arguments.options.criticalEvent : "";
		var crit = ( skipCritical ) ? "" : readCriticalCss( criticalEvent );

		if ( isHot() ) {
			// In dev there is no graph; emit just the entry as JS. Critical CSS
			// is unconditionally suppressed in dev (readCriticalCss returns "").
			return {
				js: devUrl() & "/" & reReplace( arguments.entry, "^/+", "" ),
				css: [],
				preload: [],
				criticalCss: crit
			};
		}

		var renderPreload = arguments.options.keyExists( "renderModulePreload" ) ? arguments.options.renderModulePreload : variables.settings.renderModulePreload;
		var includeCss    = arguments.options.keyExists( "includeImportedCss" )  ? arguments.options.includeImportedCss  : variables.settings.includeImportedCss;
		var cacheKey = "b|" & arguments.entry & "|" & renderPreload & "|" & includeCss;

		if ( !variables._bundles.keyExists( cacheKey ) ) {
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

			var entryFile = assetUrl( node.file );
			var cssList = cssBag.out.map( ( f ) => assetUrl( f ) );
			var preloadList = preloadBag.out.map( ( f ) => assetUrl( f ) );

			// CSS-only entry: the manifest's `file` IS the compiled stylesheet,
			// not a script. Route it into css[] (prepended so it renders as the
			// primary <link>) and leave js empty so renderers skip the <script>.
			if ( reFindNoCase( "\.css$", node.file ) ) {
				cssList.prepend( entryFile );
				variables._bundles[ cacheKey ] = {
					js: "",
					css: cssList,
					preload: preloadList
				};
			} else {
				variables._bundles[ cacheKey ] = {
					js: entryFile,
					css: cssList,
					preload: preloadList
				};
			}
		}

		var cached = variables._bundles[ cacheKey ];

		// Stitch criticalCss onto a fresh struct so the cached entry stays
		// pure manifest-derived data (criticalCss is event-keyed and
		// mtime-volatile in dev — caching it here would require a more
		// elaborate invalidation scheme than _bundles supports).
		return {
			js:          cached.js,
			css:         cached.css,
			preload:     cached.preload,
			criticalCss: crit
		};
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
	 * Resolve a built asset's public URL: buildPath + file, optionally prefixed
	 * with the module root so a mounted module's assets resolve wherever it is
	 * mounted. prependPath is intentionally NOT applied here — the Vite manifest
	 * already encodes each file's path relative to buildPath.
	 *
	 * @file Built file path from the manifest (e.g. "assets/app-abc.js").
	 */
	private string function assetUrl( required string file ) {
		var built   = joinPath( variables.settings.buildPath, arguments.file );
		var prepend = variables.settings.keyExists( "prependModuleRoot" )
			? variables.settings.prependModuleRoot
			: true;
		if ( prepend ) {
			built = joinPath( variables.moduleRoot, built );
		}
		return built;
	}

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
