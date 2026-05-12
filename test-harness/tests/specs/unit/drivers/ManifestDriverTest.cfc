component extends="coldbox.system.testing.BaseTestCase" appMapping="/" {

	function beforeAll(){
		super.beforeAll();
		setup();
		variables.wirebox  = getController().getWireBox();
		variables.store    = wirebox.getInstance( "ManifestStore@mixr" );
		variables.renderer = wirebox.getInstance( "TagRenderer@mixr" );
		variables.watcher  = wirebox.getInstance( "HotFileWatcher@mixr" );
	}

	function buildDriver( required struct settings, string moduleRoot = "" ){
		// merge defaults the facade would have applied
		structAppend(
			arguments.settings,
			{
				devMode     : false,
				cache       : { enabled : true, devCheckInterval : 2000 },
				criticalCss : {
					enabled : false,
					path    : "/tests/resources/critical",
					suffix  : ".critical.css"
				}
			},
			false
		);
		return wirebox.getInstance(
			name          = "ManifestDriver@mixr",
			initArguments = {
				settings   : arguments.settings,
				moduleRoot : arguments.moduleRoot,
				store      : variables.store,
				watcher    : variables.watcher,
				renderer   : variables.renderer
			}
		);
	}

	function run(){
		describe( "ManifestDriver", function(){
			it( "resolves an asset from a flat manifest", function(){
				var d = buildDriver( {
					manifestPath      : "/tests/resources/mix-manifest.json",
					prependModuleRoot : false,
					prependPath       : ""
				} );
				expect( d.path( "/tests/asset.js" ) ).toBe( "/tests/asset.js?id=97075299beff243f0162befb209c2391" );
			} );

			it( "throws ManifestAssetNotFound for unknown keys", function(){
				var d = buildDriver( {
					manifestPath      : "/tests/resources/mix-manifest.json",
					prependModuleRoot : false,
					prependPath       : ""
				} );
				expect( () => d.path( "/does/not/exist.js" ) ).toThrow( type = "ManifestAssetNotFound" );
			} );

			it( "throws ManifestNotFound when file is missing", function(){
				var d = buildDriver( {
					manifestPath      : "/tests/resources/missing-manifest.json",
					prependModuleRoot : false,
					prependPath       : ""
				} );
				expect( () => d.path( "/anything.js" ) ).toThrow( type = "ManifestNotFound" );
			} );

			it( "applies prependPath and module root", function(){
				var d = buildDriver(
					settings = {
						manifestPath      : "/public/mix-manifest.json",
						prependModuleRoot : true,
						prependPath       : "/includes"
					},
					moduleRoot = "/modules_app/fooModule"
				);
				// fooModule's manifest maps css/foo.css -> hashed
				expect( d.path( "css/foo.css" ) ).toBe( "/modules_app/fooModule/includes/css/foo.28fc241b1431baefb2a9b4307ed9cff1.css" );
			} );

			it( "caches resolved paths after first lookup", function(){
				var d = buildDriver( {
					manifestPath      : "/tests/resources/mix-manifest.json",
					prependModuleRoot : false,
					prependPath       : ""
				} );
				var a = d.path( "/tests/asset.js" );
				var b = d.path( "/tests/asset.js" );
				expect( a ).toBe( b );
			} );

			it( "isHot() is always false for the manifest driver", function(){
				var d = buildDriver( {
					manifestPath      : "/tests/resources/mix-manifest.json",
					prependModuleRoot : false,
					prependPath       : ""
				} );
				expect( d.isHot() ).toBeFalse();
			} );

			describe( "critical CSS", function(){
				it( "for a CSS asset: emits inline <style> + preload-swap when enabled and file exists", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.tags( "/css/app.css", { criticalEvent: "main.index" } );
					expect( html ).toInclude( "<style>" );
					expect( html ).toInclude( ".hero{color:##222" );
					expect( html ).toInclude( "rel=""preload""" );
					// Every rel="stylesheet" must be in a <noscript> (the fallback).
					expect( arrayLen( reMatch( "rel=""stylesheet""", html ) ) )
						.toBe( arrayLen( reMatch( "<noscript><link rel=""stylesheet""", html ) ) );
				} );

				it( "for a JS asset: emits inline <style> (route-keyed) + standard <script>", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.tags( "/tests/asset.js", { criticalEvent: "main.index" } );
					expect( html ).toInclude( "<style>" );
					expect( html ).toInclude( ".hero{color:##222" );
					expect( html ).toInclude( "<script src=""/tests/asset.js" );
				} );

				it( "falls back to standard output when no event in context", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.tags( "/css/app.css" );
					expect( html ).toInclude( "rel=""stylesheet""" );
					expect( html ).notToInclude( "<style>" );
				} );

				it( "falls back to standard output when criticalCss.enabled is false (default)", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : ""
					} );
					var html = d.tags( "/css/app.css", { criticalEvent: "main.index" } );
					expect( html ).toInclude( "rel=""stylesheet""" );
					expect( html ).notToInclude( "<style>" );
				} );
			} );

			describe( "bundle().criticalCss", function(){
				it( "always exposes a criticalCss key (empty by default)", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : ""
					} );
					var b = d.bundle( "/tests/asset.js" );
					expect( b ).toHaveKey( "criticalCss" );
					expect( b.criticalCss ).toBe( "" );
					expect( b.css ).toBeEmpty();
					expect( b.preload ).toBeEmpty();
				} );

				it( "carries the inline body when enabled and event has a fixture file", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var b = d.bundle( "/tests/asset.js", { criticalEvent: "main.index" } );
					expect( b.criticalCss ).toInclude( ".hero{color:##222" );
				} );

				it( "is empty when options.skipCritical=true even with a fixture present", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var b = d.bundle( "/tests/asset.js", { criticalEvent: "main.index", skipCritical: true } );
					expect( b.criticalCss ).toBe( "" );
				} );

				it( "throws MalformedCriticalCss when fixture contains </style>", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( () => d.bundle( "/tests/asset.js", { criticalEvent: "bad.injection" } ) )
						.toThrow( type = "MalformedCriticalCss" );
				} );
			} );

			describe( "cssTags() + jsTags() split", function(){
				it( "cssTags emits a stylesheet <link> for a .css asset and '' for a .js asset", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : ""
					} );
					expect( d.cssTags( "/css/app.css" ) ).toInclude( "<link rel=""stylesheet""" );
					expect( d.cssTags( "/css/app.css" ) ).toInclude( "href=""/css/app.css" );
					expect( d.cssTags( "/tests/asset.js" ) ).toBe( "" );
				} );

				it( "jsTags emits a <script> for a .js asset and '' for a .css asset", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : ""
					} );
					expect( d.jsTags( "/tests/asset.js" ) ).toInclude( "<script src=""/tests/asset.js" );
					expect( d.jsTags( "/css/app.css" ) ).toBe( "" );
				} );

				it( "cssTags + jsTags equals tags() for the same asset (CSS asset)", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : ""
					} );
					var combined = d.cssTags( "/css/app.css" ) & d.jsTags( "/css/app.css" );
					expect( combined ).toBe( d.tags( "/css/app.css" ) );
				} );

				it( "cssTags + jsTags equals tags() for the same asset (JS asset)", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : ""
					} );
					var combined = d.cssTags( "/tests/asset.js" ) & d.jsTags( "/tests/asset.js" );
					expect( combined ).toBe( d.tags( "/tests/asset.js" ) );
				} );

				it( "cssTags + jsTags equals tags() for a CSS asset with critical CSS enabled", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var combined = d.cssTags( "/css/app.css", { criticalEvent: "main.index" } )
						& d.jsTags( "/css/app.css", { criticalEvent: "main.index" } );
					expect( combined ).toBe( d.tags( "/css/app.css", { criticalEvent: "main.index" } ) );
				} );

				it( "cssTags + jsTags equals tags() for a JS asset with critical CSS enabled (inline goes into cssTags)", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					// Critical inline body belongs in the head slot (cssTags); the script belongs in the body slot (jsTags).
					var head = d.cssTags( "/tests/asset.js", { criticalEvent: "main.index" } );
					var body = d.jsTags( "/tests/asset.js", { criticalEvent: "main.index" } );
					expect( head ).toInclude( "<style>" );
					expect( body ).toInclude( "<script src=""/tests/asset.js" );
					expect( head & body ).toBe( d.tags( "/tests/asset.js", { criticalEvent: "main.index" } ) );
				} );
			} );

			describe( "criticalCss(options) driver method", function(){
				it( "returns the inline body for the resolved event when enabled", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( d.criticalCss( { criticalEvent: "main.index" } ) ).toInclude( ".hero{color:##222" );
				} );

				it( "returns '' when no event is provided", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : "",
						criticalCss       : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( d.criticalCss() ).toBe( "" );
				} );

				it( "returns '' when criticalCss.enabled is false", function(){
					var d = buildDriver( {
						manifestPath      : "/tests/resources/mix-manifest.json",
						prependModuleRoot : false,
						prependPath       : ""
					} );
					expect( d.criticalCss( { criticalEvent: "main.index" } ) ).toBe( "" );
				} );
			} );
		} );
	}

}
