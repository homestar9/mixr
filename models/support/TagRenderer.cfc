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

	/**
	 * Render a critical-CSS HTML block: an inline `<style>` containing the
	 * pre-extracted above-the-fold CSS, followed by a preload+onload-swap
	 * `<link>` for each full-CSS href, with a `<noscript><link
	 * rel="stylesheet">` fallback for clients without JavaScript.
	 *
	 * The inline CSS body is NOT escaped (escaping breaks selectors). The
	 * `</style>` rejection happens at read time in `AbstractDriver.readCriticalCss()`.
	 *
	 * Pass `inlineCss = ""` to suppress the inline `<style>` (e.g. for the
	 * second + later calls in a request, when the inline has already been
	 * deduped at the facade layer). When `hrefs` is empty, only the inline
	 * `<style>` is emitted.
	 *
	 * Options:
	 *   - nonce          (string, default ""):    CSP nonce; applied to <style> and <link rel="preload">.
	 *   - fetchpriority  (boolean, default true): emit fetchpriority="high" on the preload <link>.
	 *
	 * @inlineCss   Raw critical CSS body (NOT escaped). Empty string suppresses the <style> block.
	 * @hrefs       Array of full-stylesheet URLs to async-load via preload+swap.
	 * @attributes  Extra HTML attributes for the preload <link> (escaped).
	 * @options     { nonce, fetchpriority }.
	 */
	string function criticalCssTags( required string inlineCss, required array hrefs, struct attributes = {}, struct options = {} ) {
		var nonce         = arguments.options.keyExists( "nonce" )         ? arguments.options.nonce         : "";
		var fetchpriority = arguments.options.keyExists( "fetchpriority" ) ? arguments.options.fetchpriority : true;

		var out = createObject( "java", "java.lang.StringBuilder" ).init();

		if ( len( arguments.inlineCss ) ) {
			out.append( inlineStyleTag( arguments.inlineCss, nonce ) );
		}
		for ( var href in arguments.hrefs ) {
			out.append( preloadSwapTag( href, nonce, fetchpriority, arguments.attributes ) );
		}
		return out.toString();
	}

	/**
	 * Render just the CSS slice of a Vite bundle: inline `<style>` (when
	 * `inlineCss` is non-empty) + preload-swap `<link>`s for each CSS href,
	 * OR a plain `<link rel="stylesheet">` per href when `inlineCss` is empty.
	 *
	 * Composes with `viteJsTags()` so callers splitting head/body get the
	 * same bytes as `viteProductionTags()` / `viteCriticalProductionTags()`
	 * combined. Returns "" when both `inlineCss` and `bundle.css` are empty.
	 *
	 * @inlineCss  Raw critical CSS body. Empty string emits plain stylesheet links.
	 * @bundle     Normalized bundle struct as produced by ViteDriver.bundle().
	 * @attributes Extra HTML attributes for plain `<link rel="stylesheet">` (escaped).
	 * @options    { nonce, fetchpriority }.
	 */
	string function viteCssTags( required string inlineCss, required struct bundle, struct attributes = {}, struct options = {} ) {
		var nonce         = arguments.options.keyExists( "nonce" )         ? arguments.options.nonce         : "";
		var fetchpriority = arguments.options.keyExists( "fetchpriority" ) ? arguments.options.fetchpriority : true;

		var out = createObject( "java", "java.lang.StringBuilder" ).init();

		if ( len( arguments.inlineCss ) ) {
			out.append( inlineStyleTag( arguments.inlineCss, nonce ) );
			for ( var href in arguments.bundle.css ) {
				out.append( preloadSwapTag( href, nonce, fetchpriority, {} ) );
			}
		} else {
			for ( var href in arguments.bundle.css ) {
				out.append( linkTag( href = href, rel = "stylesheet", extraAttrs = arguments.attributes ) );
			}
		}

		return out.toString();
	}

	/**
	 * Render just the JS slice of a Vite bundle: `<link rel="modulepreload">`
	 * for each imported chunk, followed by the entry `<script type="module">`.
	 *
	 * Composes with `viteCssTags()` so the concatenation matches the bytes
	 * of `viteProductionTags()` (or `viteCriticalProductionTags()` when the
	 * critical branch is also active).
	 *
	 * @bundle     Normalized bundle struct as produced by ViteDriver.bundle().
	 * @attributes Extra HTML attributes for the entry `<script>` (escaped).
	 */
	string function viteJsTags( required struct bundle, struct attributes = {} ) {
		var out = createObject( "java", "java.lang.StringBuilder" ).init();

		for ( var href in arguments.bundle.preload ) {
			out.append( linkTag( href = href, rel = "modulepreload" ) );
		}
		out.append( scriptTag(
			src        = arguments.bundle.js,
			type       = "module",
			extraAttrs = arguments.attributes
		) );

		return out.toString();
	}

	/**
	 * Render a Vite production tag set with critical-CSS handling: an inline
	 * `<style>` (when `inlineCss` is non-empty) replaces the standard CSS
	 * `<link rel="stylesheet">` block; full-CSS hrefs are async-loaded via
	 * preload+swap. Modulepreload + entry `<script type="module">` are
	 * preserved bit-exact from `viteProductionTags()`.
	 *
	 * When `inlineCss == ""` AND `bundle.css` is empty, output is identical
	 * to `viteProductionTags()` for the same bundle.
	 *
	 * @inlineCss   Raw critical CSS body. Empty string suppresses the <style>.
	 * @bundle      Normalized bundle struct as produced by ViteDriver.bundle().
	 * @attributes  Extra HTML attributes for the entry <script> (escaped).
	 * @options     { nonce, fetchpriority }.
	 */
	string function viteCriticalProductionTags( required string inlineCss, required struct bundle, struct attributes = {}, struct options = {} ) {
		var nonce         = arguments.options.keyExists( "nonce" )         ? arguments.options.nonce         : "";
		var fetchpriority = arguments.options.keyExists( "fetchpriority" ) ? arguments.options.fetchpriority : true;

		var out = createObject( "java", "java.lang.StringBuilder" ).init();

		if ( len( arguments.inlineCss ) ) {
			out.append( inlineStyleTag( arguments.inlineCss, nonce ) );
		}
		for ( var href in arguments.bundle.css ) {
			out.append( preloadSwapTag( href, nonce, fetchpriority, {} ) );
		}
		for ( var href in arguments.bundle.preload ) {
			out.append( linkTag( href = href, rel = "modulepreload" ) );
		}
		out.append( scriptTag(
			src        = arguments.bundle.js,
			type       = "module",
			extraAttrs = arguments.attributes
		) );

		return out.toString();
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

	/**
	 * Render an inline `<style>` block. The CSS body is intentionally NOT
	 * escaped (escaping would break selectors). The `</style>` injection
	 * guard runs at read time in `AbstractDriver.readCriticalCss()`.
	 *
	 * @css   Raw CSS body.
	 * @nonce Optional CSP nonce.
	 */
	private string function inlineStyleTag( required string css, string nonce = "" ) {
		var attrs = "";
		if ( len( arguments.nonce ) ) attrs &= ' nonce="' & escape( arguments.nonce ) & '"';
		return "<style" & attrs & ">" & arguments.css & "</style>";
	}

	/**
	 * Render the preload+onload-swap pair for one async-loaded stylesheet:
	 * a `<link rel="preload" as="style" ... onload="...">` plus a
	 * `<noscript><link rel="stylesheet" ...></noscript>` fallback.
	 *
	 * Defaults to `fetchpriority="high"` on the preload link (Chrome/Edge/Safari).
	 *
	 * @href          Full-stylesheet URL.
	 * @nonce         Optional CSP nonce.
	 * @fetchpriority Emit fetchpriority="high" on the preload link when true.
	 * @extraAttrs    Extra HTML attributes for the preload <link> (escaped).
	 */
	private string function preloadSwapTag(
		required string href,
		string nonce = "",
		boolean fetchpriority = true,
		struct extraAttrs = {}
	) {
		var preloadAttrs = ' rel="preload" as="style" href="' & escape( arguments.href ) & '"';
		preloadAttrs &= ' onload="this.onload=null;this.rel=''stylesheet''"';
		if ( arguments.fetchpriority ) preloadAttrs &= ' fetchpriority="high"';
		if ( len( arguments.nonce ) )  preloadAttrs &= ' nonce="' & escape( arguments.nonce ) & '"';
		preloadAttrs &= renderAttrs( arguments.extraAttrs );

		var noscriptInner = ' rel="stylesheet" href="' & escape( arguments.href ) & '"';

		return "<link" & preloadAttrs & " />"
			& "<noscript><link" & noscriptInner & " /></noscript>";
	}

}
