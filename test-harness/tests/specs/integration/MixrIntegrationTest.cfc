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

			it( "resolves a Vite production entry from the vite submodule", function(){
				var p = mixr.path( entry = "resources/js/app.js", moduleName = "vite" );
				expect( p ).toInclude( "/includes/build/assets/app-PROD123.js" );
			} );

			it( "renders Vite production tags from the vite submodule", function(){
				var html = mixr.tags( entry = "resources/js/app.js", moduleName = "vite" );
				expect( html ).toInclude( "app-PROD123.css" );
				expect( html ).toInclude( "vendor-VEND456.js" );
				expect( html ).toInclude( "app-PROD123.js" );
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

			describe( "global mixr() helper", function(){
				// All four call shapes are exercised in a single handler action
				// to avoid TestBox + Adobe 2021 stub regeneration issues with
				// multiple execute() calls in the same suite.
				it( "resolves assets for the current module and across modules via moduleName", function(){
					var e = execute( event = "main.mixrHelperAllShapes", renderResults = false );

					// no moduleName → current module (root)
					expect( e.getPrivateValue( "mixrCurrent" ) ).toInclude( "/tests/asset.js?id=" );

					// fluent, no moduleName
					expect( e.getPrivateValue( "mixrCurrentFluent" ) ).toInclude( "/tests/asset.js?id=" );

					// legacy form with explicit moduleName → different module
					expect( e.getPrivateValue( "mixrOtherLegacy" ) ).toInclude( "/includes/build/assets/app-PROD123.js" );

					// fluent form with explicit moduleName → different module
					expect( e.getPrivateValue( "mixrOtherFluent" ) ).toInclude( "/includes/build/assets/app-PROD123.js" );
				} );
			} );
		} );
	}

}
