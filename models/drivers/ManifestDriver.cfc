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
	 * @entry   Manifest source key.
	 * @options { as: "auto"|"css"|"js", attributes: { … extra HTML attrs } }.
	 */
	string function tags( required string entry, struct options = {} ) {
		var as    = arguments.options.keyExists( "as" )         ? arguments.options.as         : "auto";
		var attrs = arguments.options.keyExists( "attributes" ) ? arguments.options.attributes : {};
		var cacheKey = arguments.entry & "|" & as & "|" & hashStruct( attrs );

		if ( variables._tags.keyExists( cacheKey ) ) return variables._tags[ cacheKey ];

		var href = path( arguments.entry );
		var html = variables.renderer.manifestTag( href = href, as = as, attributes = attrs );
		variables._tags[ cacheKey ] = html;
		return html;
	}

	/**
	 * Return a normalized bundle struct. The flat-manifest driver has no
	 * concept of imported chunks, so css and preload are always empty.
	 *
	 * @entry   Manifest source key.
	 * @options Reserved for future use; ignored by this driver.
	 */
	struct function bundle( required string entry, struct options = {} ) {
		// Manifest driver has no concept of imported chunks; return a minimal
		// shape so callers using bundle() don't have to special-case.
		return { js: path( arguments.entry ), css: [], preload: [] };
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
	 * Stable hash of an attributes struct, used as part of the tag cache key.
	 *
	 * @s Attributes struct.
	 */
	private string function hashStruct( required struct s ) {
		if ( arguments.s.isEmpty() ) return "";
		return hash( serializeJson( arguments.s ) );
	}

}
