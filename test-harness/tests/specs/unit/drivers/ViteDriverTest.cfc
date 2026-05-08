component extends="coldbox.system.testing.BaseTestCase" appMapping="/" {

	function beforeAll(){
		super.beforeAll();
		setup();
		variables.wirebox  = getController().getWireBox();
		variables.store    = wirebox.getInstance( "ManifestStore@mixr" );
		variables.renderer = wirebox.getInstance( "TagRenderer@mixr" );
		variables.watcher  = wirebox.getInstance( "HotFileWatcher@mixr" );
	}

	function buildDriver( required struct settings ){
		structAppend(
			arguments.settings,
			{
				devMode             : false,
				renderModulePreload : true,
				includeImportedCss  : true,
				devServerUrl        : "",
				hotFilePath         : "/tests/resources/vite/__no_hot__",
				buildPath           : "/includes/build",
				cache               : { enabled : true, devCheckInterval : 2000 },
				criticalCss         : {
					enabled : false,
					path    : "/tests/resources/critical",
					suffix  : ".critical.css"
				}
			},
			false
		);
		return wirebox.getInstance(
			name          = "ViteDriver@mixr",
			initArguments = {
				settings   : arguments.settings,
				moduleRoot : "",
				store      : variables.store,
				watcher    : variables.watcher,
				renderer   : variables.renderer
			}
		);
	}

	function run(){
		describe( "ViteDriver", function(){
			it( "resolves a production entry to its built file under buildPath", function(){
				var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
				expect( d.path( "resources/js/app.js" ) ).toBe( "/includes/build/assets/app-abc123.js" );
			} );

			it( "throws EntryNotFound for unknown entry", function(){
				var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
				expect( () => d.path( "resources/js/missing.js" ) ).toThrow( type = "EntryNotFound" );
			} );

			it( "throws MalformedManifest for invalid JSON", function(){
				var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-malformed.json" } );
				expect( () => d.path( "anything" ) ).toThrow( type = "MalformedManifest" );
			} );

			it( "aggregates CSS from entry and recursively imported chunks", function(){
				var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
				var b = d.bundle( "resources/js/app.js" );
				expect( b.css ).toHaveLength( 3 );
				expect( b.css[ 1 ] ).toInclude( "app-abc123.css" );
				expect( b.css[ 2 ] ).toInclude( "vendor-def456.css" );
				expect( b.css[ 3 ] ).toInclude( "shared-ghi789.css" );
			} );

			it( "skips imported CSS when includeImportedCss is false", function(){
				var d = buildDriver( {
					manifestPath       : "/tests/resources/vite/manifest-with-imports.json",
					includeImportedCss : false
				} );
				var b = d.bundle( "resources/js/app.js" );
				expect( b.css ).toHaveLength( 1 );
				expect( b.css[ 1 ] ).toInclude( "app-abc123.css" );
			} );

			it( "produces modulepreload list of imported chunk JS", function(){
				var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
				var b = d.bundle( "resources/js/app.js" );
				expect( b.preload ).toHaveLength( 2 );
				expect( b.preload[ 1 ] ).toInclude( "vendor-def456.js" );
				expect( b.preload[ 2 ] ).toInclude( "shared-ghi789.js" );
			} );

			it( "omits modulepreload list when renderModulePreload=false", function(){
				var d = buildDriver( {
					manifestPath        : "/tests/resources/vite/manifest-with-imports.json",
					renderModulePreload : false
				} );
				var b = d.bundle( "resources/js/app.js" );
				expect( b.preload ).toBeEmpty();
			} );

			it( "renders production HTML tags with css, preload, and module script", function(){
				var d    = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
				var html = d.tags( "resources/js/app.js" );
				expect( html ).toInclude( "<link rel=""stylesheet"" href=""/includes/build/assets/app-abc123.css""" );
				expect( html ).toInclude( "<link rel=""modulepreload"" href=""/includes/build/assets/vendor-def456.js""" );
				expect( html ).toInclude( "<script type=""module"" src=""/includes/build/assets/app-abc123.js""" );
			} );

			it( "renders dev-server tag when hot file is present", function(){
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json",
					hotFilePath  : "/tests/resources/vite/hot",
					devMode      : true
				} );
				expect( d.isHot() ).toBeTrue();
				var html = d.tags( "resources/js/app.js" );
				expect( html ).toInclude( "src=""http://127.0.0.1:5173/resources/js/app.js""" );
				expect( html ).notToInclude( "<link rel" );
			} );

			it( "viteClient() returns @vite/client tag in dev, empty in prod", function(){
				var prod = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
				expect( prod.viteClient() ).toBe( "" );

				var dev = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json",
					hotFilePath  : "/tests/resources/vite/hot",
					devMode      : true
				} );
				expect( dev.viteClient() ).toInclude( "/@vite/client" );
			} );

			it( "caches bundle results between calls", function(){
				var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
				var a = d.bundle( "resources/js/app.js" );
				var b = d.bundle( "resources/js/app.js" );
				expect( a ).toBe( b );
			} );

			describe( "critical CSS", function(){
				it( "emits inline <style> + preload-swap when enabled and a fixture file exists for the event", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.tags( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( html ).toInclude( "<style>" );
					expect( html ).toInclude( ".hero{color:##222" );
					expect( html ).toInclude( "rel=""preload""" );
					expect( html ).toInclude( "as=""style""" );
					expect( html ).toInclude( "fetchpriority=""high""" );
					// Every <link rel="stylesheet"> must be wrapped in <noscript> — no bare form.
					expect( arrayLen( reMatch( "<link rel=""stylesheet""", html ) ) )
						.toBe( arrayLen( reMatch( "<noscript><link rel=""stylesheet""", html ) ) );
					// modulepreload + entry script preserved
					expect( html ).toInclude( "<link rel=""modulepreload""" );
					expect( html ).toInclude( "<script type=""module""" );
				} );

				it( "falls back to standard tags() output when critical file missing for the event", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.tags( "resources/js/app.js", { criticalEvent: "missing.event" } );
					expect( html ).toInclude( "<link rel=""stylesheet""" );
					expect( html ).notToInclude( "<style>" );
				} );

				it( "falls back to standard tags() output when criticalCss.enabled is false (default)", function(){
					var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
					var html = d.tags( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( html ).toInclude( "<link rel=""stylesheet""" );
					expect( html ).notToInclude( "<style>" );
				} );

				it( "options.skipCritical=true forces standard output even when file exists", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.tags( "resources/js/app.js", {
						criticalEvent : "main.index",
						skipCritical  : true
					} );
					expect( html ).toInclude( "<link rel=""stylesheet""" );
					expect( html ).notToInclude( "<style>" );
				} );

				it( "in dev mode (isHot=true) skips critical regardless of file presence", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						hotFilePath  : "/tests/resources/vite/hot",
						devMode      : true,
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( d.isHot() ).toBeTrue();
					var html = d.tags( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( html ).notToInclude( "<style>" );
					expect( html ).toInclude( "src=""http://127.0.0.1:5173/resources/js/app.js""" );
				} );

				it( "throws MalformedCriticalCss when critical file contains </style>", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( () => d.tags( "resources/js/app.js", { criticalEvent: "bad.injection" } ) )
						.toThrow( type = "MalformedCriticalCss" );
				} );

				it( "criticalSuppressInline=true emits preload-swap CSS without the <style> block", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.tags( "resources/js/app.js", {
						criticalEvent          : "main.index",
						criticalSuppressInline : true
					} );
					expect( html ).notToInclude( "<style>" );
					expect( html ).toInclude( "rel=""preload""" );
					expect( html ).toInclude( "as=""style""" );
				} );

				it( "_criticalCache is cleared by clearCaches()", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					// prime the cache
					d.tags( "resources/js/app.js", { criticalEvent: "main.index" } );
					d.clearCaches();
					// re-render — should still work after cache flush
					var html = d.tags( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( html ).toInclude( "<style>" );
				} );
			} );
		} );
	}

}
