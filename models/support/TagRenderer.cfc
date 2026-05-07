/**
 * TagRenderer
 *
 * Pure HTML tag rendering. Drivers produce normalized "bundle" structs and
 * pass them here for HTML serialization. Keeps drivers free of HTML concerns
 * and gives one place to audit attribute escaping.
 */
component singleton {

	/**
	 * Constructor. Singleton; called once by WireBox at boot.
	 */
	TagRenderer function init() {
		return this;
	}

	/**
	 * Render a Vite production tag set: CSS <link>s, modulepreload <link>s,
	 * and the entry <script type="module">.
	 *
	 * bundle = {
	 *   js:      "/includes/build/assets/app-abc.js",
	 *   css:     [ "/includes/build/assets/app-abc.css", ... ],
	 *   preload: [ "/includes/build/assets/vendor-def.js", ... ]
	 * }
	 *
	 * @bundle     Normalized bundle struct as produced by ViteDriver.bundle().
	 * @attributes Extra HTML attributes to add to the <script> tag (escaped).
	 */
	string function viteProductionTags( required struct bundle, struct attributes = {} ) {
		var out = createObject( "java", "java.lang.StringBuilder" ).init();

		for ( var href in arguments.bundle.css ) {
			out.append( linkTag( href = href, rel = "stylesheet" ) );
		}
		for ( var href in arguments.bundle.preload ) {
			out.append( linkTag( href = href, rel = "modulepreload" ) );
		}
		out.append( scriptTag(
			src = arguments.bundle.js,
			type = "module",
			extraAttrs = arguments.attributes
		) );

		return out.toString();
	}

	/**
	 * Render Vite dev-mode tags. Always emits the entry script; the
	 * @vite/client tag is rendered separately (once per request) by the
	 * facade.
	 *
	 * @devUrl     Vite dev server base URL (no trailing slash).
	 * @entry      Vite source key.
	 * @attributes Extra HTML attributes to add to the <script> tag (escaped).
	 */
	string function viteDevTags( required string devUrl, required string entry, struct attributes = {} ) {
		return scriptTag(
			src = arguments.devUrl & "/" & reReplace( arguments.entry, "^/+", "" ),
			type = "module",
			extraAttrs = arguments.attributes
		);
	}

	/**
	 * Render <script type="module" src="<devUrl>/@vite/client"></script>.
	 *
	 * @devUrl Vite dev server base URL (no trailing slash).
	 */
	string function viteClientTag( required string devUrl ) {
		return scriptTag( src = arguments.devUrl & "/@vite/client", type = "module" );
	}

	/**
	 * Render a single tag for the manifest driver based on extension (or the
	 * explicit `as` argument).
	 *
	 * @href       Resolved asset URL.
	 * @as         "auto" | "css" | "js". Auto picks based on file extension.
	 * @attributes Extra HTML attributes (escaped).
	 */
	string function manifestTag( required string href, string as = "auto", struct attributes = {} ) {
		var kind = arguments.as == "auto" ? inferKind( arguments.href ) : arguments.as;
		if ( kind == "css" ) {
			return linkTag( href = arguments.href, rel = "stylesheet", extraAttrs = arguments.attributes );
		}
		return scriptTag( src = arguments.href, extraAttrs = arguments.attributes );
	}

	/* ------------------------------------------------------------------ */

	/**
	 * Build a <script> tag string with escaped attributes.
	 *
	 * @src        Script src URL.
	 * @type       Optional `type` attribute (e.g. "module"); omitted when empty.
	 * @extraAttrs Extra HTML attributes (escaped).
	 */
	private string function scriptTag( required string src, string type = "", struct extraAttrs = {} ) {
		var attrs = "";
		if ( len( arguments.type ) ) attrs &= ' type="' & escape( arguments.type ) & '"';
		attrs &= ' src="' & escape( arguments.src ) & '"';
		attrs &= renderAttrs( arguments.extraAttrs );
		return "<script" & attrs & "></script>";
	}

	/**
	 * Build a <link> tag string with escaped attributes.
	 *
	 * @href       Link href URL.
	 * @rel        Required rel value (e.g. "stylesheet", "modulepreload").
	 * @extraAttrs Extra HTML attributes (escaped).
	 */
	private string function linkTag( required string href, required string rel, struct extraAttrs = {} ) {
		var attrs = ' rel="' & escape( arguments.rel ) & '"' & ' href="' & escape( arguments.href ) & '"';
		attrs &= renderAttrs( arguments.extraAttrs );
		return "<link" & attrs & " />";
	}

	/**
	 * Render a struct of attributes as space-prefixed name="value" pairs.
	 * Boolean true values are rendered as bare attribute names; false omits.
	 * All values are HTML-escaped.
	 *
	 * @attrs Struct of attribute name -> value.
	 */
	private string function renderAttrs( required struct attrs ) {
		if ( arguments.attrs.isEmpty() ) return "";
		var out = "";
		for ( var key in arguments.attrs ) {
			var v = arguments.attrs[ key ];
			if ( isBoolean( v ) && !isNumeric( v ) ) {
				if ( v ) out &= " " & lcase( key );
				continue;
			}
			out &= " " & lcase( key ) & '="' & escape( toString( v ) ) & '"';
		}
		return out;
	}

	/**
	 * Infer the asset kind ("css" or "js") from a URL's file extension,
	 * stripping any query string or fragment first.
	 *
	 * @href Resolved asset URL.
	 */
	private string function inferKind( required string href ) {
		var path = listFirst( arguments.href, "?##" );
		if ( reFindNoCase( "\.css$", path ) ) return "css";
		return "js";
	}

	/**
	 * Minimal HTML escape for attribute values: &, <, >, ", '.
	 *
	 * @value Raw attribute value.
	 */
	private string function escape( required string value ) {
		return replaceList( arguments.value, '&,<,>,",''', "&amp;,&lt;,&gt;,&quot;,&##39;" );
	}

}
