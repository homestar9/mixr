/**
 * ManifestDriver
 *
 * Resolves assets from a flat src→dist JSON manifest as produced by Laravel
 * Mix, ColdBox Elixir, Webpack manifest plugins, or any custom bundler that
 * writes the same shape.
 *
 * This is the v2.x behavior preserved into 3.0 with one structural change:
 * prependPath / prependModuleRoot only apply to this driver (they have no
 * meaning for Vite). Errors keep their original types so existing catch
 * blocks continue to work.
 */
component extends="AbstractDriver" {

	/**
	 * Resolve a single asset to its real, hashed URL by looking it up in the
	 * flat manifest, then prepending moduleRoot/prependPath as configured.
	 *
	 * Throws ManifestAssetNotFound when the key is missing.
	 *
	 * @asset   Manifest source key (e.g. "/js/app.js").
	 * @options Reserved for future use; ignored by this driver.
	 */
	string function path( required string asset, struct options = {} ) {
		var key = arguments.asset;
		if ( variables._paths.keyExists( key ) ) return variables._paths[ key ];

		var manifest = getManifest();
		if ( !manifest.keyExists( arguments.asset ) ) {
			throw(
				message = "Asset file not found in manifest",
				type    = "ManifestAssetNotFound",
				detail  = "Looked for #arguments.asset# in #absoluteManifestPath()#"
			);
		}

		var resolved = manifest[ arguments.asset ];

		// Build output path. Note: prependModuleRoot/prependPath behave
		// idiomatically — joinPath collapses duplicate slashes, so callers no
		// longer need to worry about trailing slashes the way 2.x did.
		var head = "";
		if ( variables.settings.prependModuleRoot ) head = variables.moduleRoot;
		var built = head & "/" & variables.settings.prependPath & "/" & resolved;
		built = reReplace( built, "/{2,}", "/", "all" );
		if ( !built.startsWith( "/" ) ) built = "/" & built;

		variables._paths[ key ] = built;
		return built;
	}

	/**
	 * Render an HTML tag for a single asset. Picks <link> for CSS and
	 * <script> for everything else based on file extension (or the explicit
	 * `as` option).
	 *
	 * When `settings.criticalCss.enabled` is true and a critical CSS file
	 * exists for the current event (via `options.criticalEvent`):
	 *   - CSS asset:  inline <style> + preload-swap <link> for this href + <noscript> fallback.
	 *   - JS asset:   inline <style> (route-keyed; independent of entry kind) + standard <script>.
	 * `options.skipCritical = true` forces standard output for this call.
	 *
	 * @entry   Manifest source key.
	 * @options { as: "auto"|"css"|"js", attributes,
	 *           criticalEvent, criticalSuppressInline, skipCritical, nonce }.
	 */
	string function tags( required string entry, struct options = {} ) {
		var as    = arguments.options.keyExists( "as" )         ? arguments.options.as         : "auto";
		var attrs = arguments.options.keyExists( "attributes" ) ? arguments.options.attributes : {};
		var skipCritical   = arguments.options.keyExists( "skipCritical" ) ? !!arguments.options.skipCritical : false;
		var suppressInline = arguments.options.keyExists( "criticalSuppressInline" ) ? !!arguments.options.criticalSuppressInline : false;
		var criticalEvent  = arguments.options.keyExists( "criticalEvent" ) ? arguments.options.criticalEvent : "";
		var nonce          = arguments.options.keyExists( "nonce" ) ? arguments.options.nonce : "";

		var inlineCss = "";
		if ( !skipCritical ) {
			inlineCss = readCriticalCss( criticalEvent );
		}
		var emittedInline = ( len( inlineCss ) && !suppressInline );

		var cacheKey = arguments.entry & "|" & as & "|" & attrsKey( attrs )
			& "|crit:"   & ( len( inlineCss ) ? "1" : "0" )
			& "|skip:"   & ( skipCritical ? "1" : "0" )
			& "|inline:" & ( emittedInline ? "1" : "0" )
			& "|evt:"    & criticalEvent
			& "|nonce:"  & nonce;

		if ( variables._tags.keyExists( cacheKey ) ) return variables._tags[ cacheKey ];

		var href = path( arguments.entry );
		var kind = ( as == "auto" ) ? ( reFindNoCase( "\.css(\?|##|$)", href ) ? "css" : "js" ) : as;
		var html = "";

		if ( len( inlineCss ) && kind == "css" ) {
			// CSS asset, critical mode: inline <style> (when not suppressed)
			// + preload-swap <link> + <noscript> fallback.
			html = variables.renderer.criticalCssTags(
				inlineCss  = emittedInline ? inlineCss : "",
				hrefs      = [ href ],
				attributes = attrs,
				options    = { nonce: nonce }
			);
		} else if ( len( inlineCss ) && kind == "js" ) {
			// JS asset, critical mode: route-keyed inline <style> +
			// standard <script>. Inline only when not suppressed.
			var prefix = "";
			if ( emittedInline ) {
				prefix = variables.renderer.criticalCssTags(
					inlineCss  = inlineCss,
					hrefs      = [],
					options    = { nonce: nonce }
				);
			}
			html = prefix & variables.renderer.manifestTag( href = href, as = as, attributes = attrs );
		} else {
			// No critical content (or suppressed without preload need): standard output.
			html = variables.renderer.manifestTag( href = href, as = as, attributes = attrs );
		}

		variables._tags[ cacheKey ] = html;
		return html;
	}

	/**
	 * Return a normalized bundle struct. The flat-manifest driver has no
	 * concept of imported chunks, so css and preload are always empty.
	 *
	 * `criticalCss` carries the inline CSS body for the resolved event (or ""
	 * when disabled / in dev / file missing) so callers building their own
	 * tags have the same data shape as the Vite driver.
	 *
	 * @entry   Manifest source key.
	 * @options { criticalEvent, skipCritical }.
	 */
	struct function bundle( required string entry, struct options = {} ) {
		var skipCritical  = arguments.options.keyExists( "skipCritical" ) ? !!arguments.options.skipCritical : false;
		var criticalEvent = arguments.options.keyExists( "criticalEvent" ) ? arguments.options.criticalEvent : "";
		var crit = ( skipCritical ) ? "" : readCriticalCss( criticalEvent );

		// Manifest driver has no concept of imported chunks; return a minimal
		// shape so callers using bundle() don't have to special-case.
		return {
			js: path( arguments.entry ),
			css: [],
			preload: [],
			criticalCss: crit
		};
	}

	/**
	 * Always false — the flat-manifest driver has no dev-server concept.
	 */
	boolean function isHot() {
		return false;
	}

	/**
	 * Always empty — the flat-manifest driver has no @vite/client to render.
	 */
	string function viteClient() {
		return "";
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
