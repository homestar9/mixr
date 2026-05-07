component extends="coldbox.system.testing.BaseModelTest" {

	function run() {
		describe( "TagRenderer", function() {

			beforeEach( function( currentSpec ) {
				variables.r = createObject( "component", "mixr.models.support.TagRenderer" ).init();
			} );

			it( "renders a Vite production bundle with css, preload, and module script", function() {
				var html = r.viteProductionTags( bundle = {
					js: "/build/app.js",
					css: [ "/build/app.css" ],
					preload: [ "/build/vendor.js" ]
				} );
				expect( html ).toInclude( '<link rel="stylesheet" href="/build/app.css" />' );
				expect( html ).toInclude( '<link rel="modulepreload" href="/build/vendor.js" />' );
				expect( html ).toInclude( '<script type="module" src="/build/app.js"></script>' );
			} );

			it( "renders Vite dev tags from devUrl + entry", function() {
				var html = r.viteDevTags( devUrl = "http://localhost:5173", entry = "resources/js/app.js" );
				expect( html ).toBe( '<script type="module" src="http://localhost:5173/resources/js/app.js"></script>' );
			} );

			it( "renders @vite/client", function() {
				var html = r.viteClientTag( devUrl = "http://localhost:5173" );
				expect( html ).toInclude( "/@vite/client" );
			} );

			it( "renders a script tag for .js manifest assets and a link for .css", function() {
				expect( r.manifestTag( href = "/css/app.css" ) ).toInclude( '<link rel="stylesheet" href="/css/app.css"' );
				expect( r.manifestTag( href = "/js/app.js" ) ).toInclude( '<script src="/js/app.js"' );
			} );

			it( "applies extra attributes and HTML-escapes their values", function() {
				var html = r.viteProductionTags(
					bundle = { js: "/build/app.js", css: [], preload: [] },
					attributes = { defer: true, "data-x": "<bad>" }
				);
				expect( html ).toInclude( "defer" );
				expect( html ).toInclude( 'data-x="&lt;bad&gt;"' );
			} );

		} );
	}

}
