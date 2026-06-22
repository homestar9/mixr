component extends="coldbox.system.testing.BaseTestCase" appMapping="/" {

	function beforeAll(){
		super.beforeAll();
		setup();
		variables.wirebox = getController().getWireBox();
	}

	function run(){
		describe( "Mixr settings resolution (no cascade)", function(){
			beforeEach( function( currentSpec ){
				variables.mixr = wirebox.getInstance( "Mixr@mixr" );
				makePublic( variables.mixr, "effectiveSettings" );
				variables.mixr.refresh();
			} );

			describe( "root app", function(){
				it( "fills in defaults for keys the host did not set", function(){
					// the harness root sets driver=manifest, manifestPath=/tests/...
					// — but does NOT set, e.g., renderModulePreload. That should
					// fall back to the system default (true).
					var s = mixr.effectiveSettings( "" );
					expect( s.renderModulePreload ).toBeTrue();
					expect( s.includeImportedCss ).toBeTrue();
				} );

				it( "uses host's own values when set", function(){
					var s = mixr.effectiveSettings( "" );
					expect( s.driver ).toBe( "manifest" );
					expect( s.manifestPath ).toBe( "/tests/resources/mix-manifest.json" );
				} );

				it( "fills in default substructs key-by-key when host didn't set them", function(){
					// host did not declare cache.* — defaults should apply
					var s = mixr.effectiveSettings( "" );
					expect( s.cache.enabled ).toBeTrue();
					expect( s.cache.devCheckInterval ).toBe( 2000 );
				} );

				it( "strips the modules key from the effective struct", function(){
					var s = mixr.effectiveSettings( "" );
					expect( s ).notToHaveKey( "modules" );
				} );
			} );

			describe( "submodule with its own settings", function(){
				it( "elixir's explicit keys win; unspecified keys fall back to defaults (NOT to root)", function(){
					var s = mixr.effectiveSettings( "elixir" );
					// elixir explicitly sets these
					expect( s.manifestPath ).toBe( "/includes/rev-manifest.json" );
					expect( s.prependPath ).toBe( "/" );
					// elixir does not set driver — system default wins, NOT root's "manifest"
					expect( s.driver ).toBe( "auto" );
				} );

				it( "viteSpa's own devMode=true and driver=vite are preserved", function(){
					var s = mixr.effectiveSettings( "viteSpa" );
					expect( s.devMode ).toBeTrue();
					expect( s.driver ).toBe( "vite" );
				} );
			} );

			describe( "host modules.#encodeForHtml( "<name>" )# override", function(){
				it( "host's modules.fooModule supplies all keys to fooModule (which has no own mixr settings)", function(){
					// fooModule's ModuleConfig has no mixr settings; host declares
					// modules.fooModule = { driver: manifest, manifestPath: /public/mix-manifest.json, ... }
					var s = mixr.effectiveSettings( "fooModule" );
					expect( s.driver ).toBe( "manifest" );
					expect( s.manifestPath ).toBe( "/public/mix-manifest.json" );
					expect( s.prependModuleRoot ).toBeTrue();
					expect( s.prependPath ).toBe( "/includes" );
				} );
			} );

			describe( "regression: root settings do NOT cascade to submodules", function(){
				it( "host's driver=manifest does not reach login when login has no own driver", function(){
					// login's own settings: { manifestPath : "/includes/mix-manifest.json" }
					// Host root sets driver=manifest, but login should see driver=auto (default).
					var s = mixr.effectiveSettings( "login" );
					expect( s.driver ).toBe( "auto" );
				} );

				it( "host's manifestPath does not leak into a submodule's effective settings", function(){
					// Host root manifestPath=/tests/resources/mix-manifest.json — must NOT
					// leak into login (which sets its own manifestPath).
					var s = mixr.effectiveSettings( "login" );
					expect( s.manifestPath ).toBe( "/includes/mix-manifest.json" );
					expect( s.manifestPath ).notToInclude( "tests/resources" );
				} );

				it( "host's prependModuleRoot=false does not leak into elixir (which sets its own prependPath but not prependModuleRoot)", function(){
					// Host root: prependModuleRoot=false. Elixir sets prependModuleRoot=true.
					// Confirms cascade is gone — root's false does not override elixir's true.
					var s = mixr.effectiveSettings( "elixir" );
					expect( s.prependModuleRoot ).toBeTrue();
				} );
			} );
		} );
	}

}
