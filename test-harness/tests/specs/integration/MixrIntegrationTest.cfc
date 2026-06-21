component extends="coldbox.system.testing.BaseTestCase" appMapping="/" {

	function beforeAll(){
		super.beforeAll();
		setup();
		variables.mixr = getController().getWireBox().getInstance( "Mixr@mixr" );
		variables.mixr.refresh();
	}

	function run(){
		describe( "Mixr 3.0 integration (Vite + manifest)", function(){
			beforeEach( function( currentSpec ){
				// Fresh ColdBox request per spec
				setup();
			} );

			it( "auto-detects the manifest driver and resolves a Mix-style path from the harness root", function(){
				// the harness root config is Mix-style; auto should pick manifest
				var p = mixr.path( "/tests/asset.js" );
				expect( p ).toInclude( "/tests/asset.js?id=" );
			} );

			it( "supports the legacy mixr() string form via the service get() method", function(){
				var p = mixr.get( "/tests/asset.js" );
				expect( p ).toInclude( "/tests/asset.js?id=" );
			} );

			it( "resolves a Vite production entry from the vite submodule, prefixed with the module root", function(){
				var root = getRequestContext().getModuleRoot( "vite" );
				var p    = mixr.path( entry = "resources/js/app.js", moduleName = "vite" );
				expect( p ).toBe( root & "/includes/build/assets/app-PROD123.js" );
				expect( p.startsWith( root & "/" ) ).toBeTrue( "path '#p#' should start with the module root '#root#'" );
			} );

			it( "renders Vite production tags from the vite submodule with module-root-prefixed hrefs", function(){
				var root = getRequestContext().getModuleRoot( "vite" );
				var html = mixr.tags( entry = "resources/js/app.js", moduleName = "vite" );
				expect( html ).toInclude( root & "/includes/build/assets/app-PROD123.css" );
				expect( html ).toInclude( root & "/includes/build/assets/vendor-VEND456.js" );
				expect( html ).toInclude( root & "/includes/build/assets/app-PROD123.js" );
			} );

			it( "detects the hot file in the viteSpa submodule and renders dev tags", function(){
				expect( mixr.isHot( "viteSpa" ) ).toBeTrue();
				var html = mixr.tags( entry = "resources/js/app.js", moduleName = "viteSpa" );
				expect( html ).toInclude( "http://127.0.0.1:5173/resources/js/app.js" );
			} );

			it( "renders @vite/client only once per request", function(){
				var event = getRequestContext();
				event.removePrivateValue( "mixr:viteClientRendered:viteSpa" );
				var first  = mixr.viteClient( "viteSpa" );
				var second = mixr.viteClient( "viteSpa" );
				expect( first ).toInclude( "/@vite/client" );
				expect( second ).toBe( "" );
			} );

			it( "supports fluent forModule() scope", function(){
				var scope = mixr.forModule( "vite" );
				expect( scope.path( "resources/js/app.js" ) ).toInclude( "app-PROD123.js" );
				expect( scope.isHot() ).toBeFalse();
			} );

			it( "preserves elixir submodule's custom config (Elixir convention)", function(){
				// elixir module overrides via its own ModuleConfig.cfc:
				//   manifestPath=/includes/rev-manifest.json, prependPath="/"
				var p = mixr.path( entry = "includes/js/elixir.js", moduleName = "elixir" );
				expect( p ).toInclude( "elixir.46ef92deb8e36cfa93b3e8a8c1bb6a4a.js" );
			} );

			it( "does not leak the root app's manifestPath into submodules", function(){
				// Regression: in 3.0 prior to the split cascade, every submodule
				// inherited the host app's manifestPath and joined it onto its
				// own moduleRoot. Here the harness root points at
				// /tests/resources/mix-manifest.json — login (which only
				// declares manifestPath itself) must NOT pick that up.
				var p = mixr.path( entry = "/css/login.css", moduleName = "login" );
				expect( p ).toInclude( "login." );
				expect( p ).notToInclude( "tests/resources" );
			} );

			it( "throws a self-documenting ManifestNotFound for a 2.x-default app (auto, no manifestPath, no manifest)", function(){
				// legacyMix declares driver:"auto" but no manifestPath, and ships
				// no Vite manifest / hot file — exactly a 2.x app that upgraded and
				// relied on the old default. The error must name the migration fix.
				var threw = false;
				try {
					mixr.path( entry = "/js/app.js", moduleName = "legacyMix" );
				} catch ( any e ) {
					threw = true;
					expect( e.type ).toBe( "ManifestNotFound" );
					expect( e.detail ).toInclude( "manifestPath" );
					expect( e.detail ).toInclude( "mix-manifest.json" );
				}
				expect( threw ).toBeTrue( "expected mixr.path to throw for the legacyMix module" );
			} );

			describe( "critical CSS (vite submodule, criticalCss.enabled=true via ModuleConfig)", function(){
				beforeEach( function( currentSpec ){
					// reset the per-request inline-dedupe flag for a clean state
					var event = getRequestContext();
					event.removePrivateValue( "mixr:criticalInlined:vite" );
				} );

				it( "inlines #encodeForHtml( "<style>" )# + emits preload-swap + #encodeForHtml( "<noscript>" )# when fixture file exists for the event", function(){
					var html = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					expect( html ).toInclude( "<style>" );
					expect( html ).toInclude( ".fold{color:##0a0" );
					expect( html ).toInclude( "rel=""preload""" );
					expect( html ).toInclude( "as=""style""" );
					expect( html ).toInclude( "fetchpriority=""high""" );
					expect( html ).toInclude( "<noscript><link rel=""stylesheet""" );
					// Every <link rel="stylesheet"> must be wrapped in <noscript> — no bare form.
					expect( arrayLen( reMatch( "<link rel=""stylesheet""", html ) ) )
						.toBe( arrayLen( reMatch( "<noscript><link rel=""stylesheet""", html ) ) );
					// JS portion preserved
					expect( html ).toInclude( "<script type=""module""" );
				} );

				it( "falls back to standard tags() output when the critical file is missing for an event", function(){
					var html = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "missing.event" }
					);
					expect( html ).notToInclude( "<style>" );
					expect( html ).toInclude( "<link rel=""stylesheet""" );
				} );

				it( "options.skipCritical=true forces standard output regardless of fixture", function(){
					var html = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index", skipCritical: true }
					);
					expect( html ).notToInclude( "<style>" );
					expect( html ).toInclude( "<link rel=""stylesheet""" );
				} );

				it( "a leading skipCritical tags() call does NOT suppress a later normal tags() inline #encodeForHtml( "<style>" )#", function(){
					// Regression: the dedupe flag used to be set eagerly on the
					// first tags() call regardless of whether it emitted an inline.
					// A leading skipCritical:true call must not suppress a later
					// real one — the flag is set only when inline is actually emitted.
					var first = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index", skipCritical: true }
					);
					expect( first ).notToInclude( "<style>" );

					var second = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					expect( second ).toInclude( "<style>" );
				} );

				it( "per-request dedupe: a second tags() call in the same request emits no inline #encodeForHtml( "<style>" )#", function(){
					var first = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					var second = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					expect( first ).toInclude( "<style>" );
					expect( second ).notToInclude( "<style>" );
					// second still emits preload-swap for the CSS
					expect( second ).toInclude( "rel=""preload""" );
				} );
			} );

			describe( "bundle().criticalCss + mixr.criticalCss() (vite submodule)", function(){
				beforeEach( function( currentSpec ){
					var event = getRequestContext();
					event.removePrivateValue( "mixr:criticalInlined:vite" );
				} );

				it( "bundle() returns the inline CSS body in the criticalCss field for the requested event", function(){
					var b = mixr.bundle(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					expect( b ).toHaveKey( "criticalCss" );
					expect( b.criticalCss ).toInclude( ".fold{color:##0a0" );
					// manifest-derived parts still populated
					expect( b.js ).toInclude( "app-PROD123.js" );
				} );

				it( "bundle() returns criticalCss='' when options.skipCritical=true", function(){
					var b = mixr.bundle(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index", skipCritical: true }
					);
					expect( b.criticalCss ).toBe( "" );
				} );

				it( "criticalCss() returns the inline body for the explicit event", function(){
					var s = mixr.criticalCss( eventName = "main.index", moduleName = "vite" );
					expect( s ).toInclude( ".fold{color:##0a0" );
				} );

				it( "criticalCss() does NOT set the dedupe flag by default", function(){
					mixr.criticalCss( eventName = "main.index", moduleName = "vite" );
					var html = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					// pure read — tags() still emits its inline
					expect( html ).toInclude( "<style>" );
				} );

				it( "criticalCss( markRendered: true ) sets the dedupe flag so a later tags() suppresses inline", function(){
					var s = mixr.criticalCss(
						eventName  = "main.index",
						moduleName = "vite",
						options    = { markRendered: true }
					);
					expect( s ).toInclude( ".fold{color:##0a0" );

					var html = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					expect( html ).notToInclude( "<style>" );
					// preload-swap still present
					expect( html ).toInclude( "rel=""preload""" );
				} );

				it( "criticalCss( markRendered: true ) does NOT set the flag when result is empty", function(){
					var event = getRequestContext();
					event.removePrivateValue( "mixr:criticalInlined:vite" );
					var s = mixr.criticalCss(
						eventName  = "missing.event",
						moduleName = "vite",
						options    = { markRendered: true }
					);
					expect( s ).toBe( "" );
					expect( event.privateValueExists( "mixr:criticalInlined:vite" ) ).toBeFalse();
				} );

				it( "fluent scope: mixr.forModule('vite').criticalCss( eventName ) resolves the same inline body", function(){
					var scope = mixr.forModule( "vite" );
					expect( scope.criticalCss( "main.index" ) ).toInclude( ".fold{color:##0a0" );
				} );
			} );

			describe( "cssTags() + jsTags() head/body split (vite submodule)", function(){
				beforeEach( function( currentSpec ){
					var event = getRequestContext();
					event.removePrivateValue( "mixr:criticalInlined:vite" );
				} );

				it( "cssTags emits CSS only; jsTags emits JS only", function(){
					var head = mixr.cssTags( entry = "resources/js/app.js", moduleName = "vite" );
					var body = mixr.jsTags( entry = "resources/js/app.js", moduleName = "vite" );

					expect( head ).toInclude( "<link rel=""stylesheet""" );
					expect( head ).toInclude( "app-PROD123.css" );
					expect( head ).notToInclude( "<script" );
					expect( head ).notToInclude( "modulepreload" );

					expect( body ).toInclude( "<script type=""module""" );
					expect( body ).toInclude( "modulepreload" );
					expect( body ).notToInclude( "rel=""stylesheet""" );
				} );

				it( "cssTags + jsTags equals tags() byte-for-byte (no critical CSS option)", function(){
					var combined = mixr.cssTags( entry = "resources/js/app.js", moduleName = "vite", options = { skipCritical: true } )
						& mixr.jsTags( entry = "resources/js/app.js", moduleName = "vite", options = { skipCritical: true } );
					var combo = mixr.tags( entry = "resources/js/app.js", moduleName = "vite", options = { skipCritical: true } );
					expect( combined ).toBe( combo );
				} );

				it( "cssTags participates in per-request dedupe: cssTags then tags() emits no second inline #encodeForHtml( "<style>" )#", function(){
					var head = mixr.cssTags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					expect( head ).toInclude( "<style>" );

					var laterTags = mixr.tags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					expect( laterTags ).notToInclude( "<style>" );
					// preload-swap link should still be there
					expect( laterTags ).toInclude( "rel=""preload""" );
				} );

				it( "jsTags does not touch the critical-CSS dedupe flag", function(){
					var event = getRequestContext();
					event.removePrivateValue( "mixr:criticalInlined:vite" );

					mixr.jsTags(
						entry      = "resources/js/app.js",
						moduleName = "vite",
						options    = { criticalEvent: "main.index" }
					);
					expect( event.privateValueExists( "mixr:criticalInlined:vite" ) ).toBeFalse();
				} );

				it( "fluent scope: mixr.forModule('vite').cssTags / jsTags work the same as facade calls", function(){
					var event = getRequestContext();
					event.removePrivateValue( "mixr:criticalInlined:vite" );

					var scope = mixr.forModule( "vite" );
					expect( scope.cssTags( "resources/js/app.js", { skipCritical: true } ) ).toInclude( "rel=""stylesheet""" );
					expect( scope.jsTags( "resources/js/app.js" ) ).toInclude( "<script type=""module""" );
				} );

				it( "in dev (viteSpa) cssTags returns '' and jsTags returns the dev-server script", function(){
					expect( mixr.cssTags( entry = "resources/js/app.js", moduleName = "viteSpa" ) ).toBe( "" );
					expect( mixr.jsTags( entry = "resources/js/app.js", moduleName = "viteSpa" ) )
						.toInclude( "http://127.0.0.1:5173/resources/js/app.js" );
				} );
			} );

			describe( "global mixr() helper", function(){
				it( "legacy string form resolves an asset for the current module", function(){
					var e = execute( event = "main.mixrCurrent", renderResults = false );
					expect( e.getPrivateValue( "mixrCurrent" ) ).toInclude( "/tests/asset.js?id=" );
				} );

				it( "fluent form resolves an asset for the current module", function(){
					var e = execute( event = "main.mixrCurrentFluent", renderResults = false );
					expect( e.getPrivateValue( "mixrCurrentFluent" ) ).toInclude( "/tests/asset.js?id=" );
				} );

				it( "legacy form with explicit moduleName resolves an asset from another module", function(){
					var e = execute( event = "main.mixrOtherLegacy", renderResults = false );
					expect( e.getPrivateValue( "mixrOtherLegacy" ) ).toInclude( "/includes/build/assets/app-PROD123.js" );
				} );

				it( "fluent form with explicit moduleName resolves an asset from another module", function(){
					var e = execute( event = "main.mixrOtherFluent", renderResults = false );
					expect( e.getPrivateValue( "mixrOtherFluent" ) ).toInclude( "/includes/build/assets/app-PROD123.js" );
				} );

				it( "fluent tags() with critical-CSS options inlines #encodeForHtml( "<style>" )# and preload-swaps the CSS link", function(){
					var e    = execute( event = "main.mixrCssWithCritical", renderResults = false );
					var crit = e.getPrivateValue( "mixrCssWithCritical" );
					expect( crit ).toInclude( "<style>" );
					expect( crit ).toInclude( ".critical" );
					expect( crit ).toInclude( "rel=""preload""" );
					expect( crit ).toInclude( "as=""style""" );
					expect( crit ).toInclude( "/css/app.css?id=" );
				} );
			} );
		} );
	}

}
