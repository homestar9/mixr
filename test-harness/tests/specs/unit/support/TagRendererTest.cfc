component extends="coldbox.system.testing.BaseTestCase" appMapping="/" {

	function beforeAll(){
		super.beforeAll();
		setup();
		variables.wirebox = getController().getWireBox();
	}

	function run(){
		describe( "TagRenderer", function(){
			beforeEach( function( currentSpec ){
				variables.r = wirebox.getInstance( "TagRenderer@mixr" );
			} );

			it( "renders a Vite production bundle with css, preload, and module script", function(){
				var html = r.viteProductionTags(
					bundle = {
						js      : "/build/app.js",
						css     : [ "/build/app.css" ],
						preload : [ "/build/vendor.js" ]
					}
				);
				expect( html ).toInclude( "<link rel=""stylesheet"" href=""/build/app.css"" />" );
				expect( html ).toInclude( "<link rel=""modulepreload"" href=""/build/vendor.js"" />" );
				expect( html ).toInclude( "<script type=""module"" src=""/build/app.js""></script>" );
			} );

			it( "renders Vite dev tags from devUrl + entry", function(){
				var html = r.viteDevTags( devUrl = "http://localhost:5173", entry = "resources/js/app.js" );
				expect( html ).toBe( "<script type=""module"" src=""http://localhost:5173/resources/js/app.js""></script>" );
			} );

			it( "renders @vite/client", function(){
				var html = r.viteClientTag( devUrl = "http://localhost:5173" );
				expect( html ).toInclude( "/@vite/client" );
			} );

			it( "renders a script tag for .js manifest assets and a link for .css", function(){
				expect( r.manifestTag( href = "/css/app.css" ) ).toInclude( "<link rel=""stylesheet"" href=""/css/app.css""" );
				expect( r.manifestTag( href = "/js/app.js" ) ).toInclude( "<script src=""/js/app.js""" );
			} );

			it( "applies extra attributes and HTML-escapes their values", function(){
				var html = r.viteProductionTags(
					bundle     = { js : "/build/app.js", css : [], preload : [] },
					attributes = { defer : true, "data-x" : "<bad>" }
				);
				expect( html ).toInclude( "defer" );
				expect( html ).toInclude( "data-x=""&lt;bad&gt;""" );
			} );

			describe( "criticalCssTags()", function(){
				it( "emits inline <style> + preload-swap + <noscript> with fetchpriority=high by default", function(){
					var html = r.criticalCssTags(
						inlineCss = ".a{color:red}",
						hrefs     = [ "/build/app.css" ]
					);
					expect( html ).toInclude( "<style>.a{color:red}</style>" );
					expect( html ).toInclude( "rel=""preload""" );
					expect( html ).toInclude( "as=""style""" );
					expect( html ).toInclude( "href=""/build/app.css""" );
					expect( html ).toInclude( "fetchpriority=""high""" );
					expect( html ).toInclude( "this.onload=null;this.rel='stylesheet'" );
					expect( html ).toInclude( "<noscript><link rel=""stylesheet"" href=""/build/app.css"" /></noscript>" );
				} );

				it( "applies CSP nonce to both <style> and preload <link>", function(){
					var html = r.criticalCssTags(
						inlineCss = ".a{}",
						hrefs     = [ "/build/app.css" ],
						options   = { nonce: "abc123" }
					);
					expect( html ).toInclude( "<style nonce=""abc123"">" );
					expect( html ).toInclude( "<link rel=""preload""" );
					expect( html ).toInclude( "nonce=""abc123""" );
				} );

				it( "skips fetchpriority when options.fetchpriority is false", function(){
					var html = r.criticalCssTags(
						inlineCss = ".a{}",
						hrefs     = [ "/build/app.css" ],
						options   = { fetchpriority: false }
					);
					expect( html ).notToInclude( "fetchpriority" );
				} );

				it( "suppresses inline <style> when inlineCss is empty (still emits preload-swap)", function(){
					var html = r.criticalCssTags(
						inlineCss = "",
						hrefs     = [ "/build/app.css" ]
					);
					expect( html ).notToInclude( "<style" );
					expect( html ).toInclude( "rel=""preload""" );
				} );

				it( "emits multiple preload-swap pairs when multiple hrefs are passed", function(){
					var html = r.criticalCssTags(
						inlineCss = ".a{}",
						hrefs     = [ "/a.css", "/b.css" ]
					);
					expect( html ).toInclude( "/a.css" );
					expect( html ).toInclude( "/b.css" );
				} );

				it( "emits only the inline <style> when hrefs is empty", function(){
					var html = r.criticalCssTags(
						inlineCss = ".x{}",
						hrefs     = []
					);
					expect( html ).toInclude( "<style>.x{}</style>" );
					expect( html ).notToInclude( "preload" );
				} );
			} );

			describe( "viteCriticalProductionTags()", function(){
				it( "replaces <link rel=stylesheet> with inline + preload-swap, preserves modulepreload + script", function(){
					var html = r.viteCriticalProductionTags(
						inlineCss = ".a{}",
						bundle    = {
							js      : "/build/app.js",
							css     : [ "/build/app.css" ],
							preload : [ "/build/vendor.js" ]
						}
					);
					expect( html ).toInclude( "<style>.a{}</style>" );
					expect( html ).toInclude( "rel=""preload""" );
					expect( html ).toInclude( "as=""style""" );
					expect( html ).toInclude( "<link rel=""modulepreload"" href=""/build/vendor.js"" />" );
					expect( html ).toInclude( "<script type=""module"" src=""/build/app.js""></script>" );
					// Every <link rel="stylesheet"> must be wrapped in <noscript> — no bare form.
					expect( arrayLen( reMatch( "<link rel=""stylesheet""", html ) ) )
						.toBe( arrayLen( reMatch( "<noscript><link rel=""stylesheet""", html ) ) );
				} );

				it( "with empty inlineCss + empty bundle.css emits the same tag set as viteProductionTags() minus the CSS link", function(){
					var html = r.viteCriticalProductionTags(
						inlineCss = "",
						bundle    = { js : "/build/app.js", css : [], preload : [ "/build/vendor.js" ] }
					);
					expect( html ).notToInclude( "<style" );
					expect( html ).notToInclude( "preload" & " " & "as=""style""" );
					expect( html ).toInclude( "<link rel=""modulepreload""" );
					expect( html ).toInclude( "<script type=""module""" );
				} );
			} );
		} );
	}

}
