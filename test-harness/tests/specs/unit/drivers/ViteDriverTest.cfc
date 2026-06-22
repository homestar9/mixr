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
				moduleRoot : arguments.moduleRoot,
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

			describe( "prependModuleRoot (mounted-module asset URLs)", function(){
				// moduleRoot prefixes BOTH the manifest/hot path (init joins
				// moduleRoot + manifestPath) and the emitted asset URLs — exactly
				// as in a real mounted module, whose manifest lives under its
				// mount root. So we frame these as a module mounted at /tests
				// (where the fixtures actually live) and express manifestPath /
				// hotFilePath relative to that mount.
				it( "prod, mounted module: prefixes path() and every bundle URL with the module root", function(){
					var d = buildDriver( { manifestPath : "/resources/vite/manifest-with-imports.json" }, "/tests" );
					expect( d.path( "resources/js/app.js" ) ).toBe( "/tests/includes/build/assets/app-abc123.js" );

					var b = d.bundle( "resources/js/app.js" );
					expect( b.js ).toBe( "/tests/includes/build/assets/app-abc123.js" );
					expect( b.css ).notToBeEmpty();
					for ( var href in b.css ) {
						expect( href.startsWith( "/tests/" ) ).toBeTrue( "css href '#href#' should start with /tests/" );
					}
					expect( b.preload ).notToBeEmpty();
					for ( var href in b.preload ) {
						expect( href.startsWith( "/tests/" ) ).toBeTrue( "preload href '#href#' should start with /tests/" );
					}
				} );

				it( "prod, mounted module, prependModuleRoot=false: URLs are NOT prefixed", function(){
					var d = buildDriver(
						{
							manifestPath      : "/resources/vite/manifest-with-imports.json",
							prependModuleRoot : false
						},
						"/tests"
					);
					expect( d.path( "resources/js/app.js" ) ).toBe( "/includes/build/assets/app-abc123.js" );

					var b = d.bundle( "resources/js/app.js" );
					expect( b.js ).toBe( "/includes/build/assets/app-abc123.js" );
					for ( var href in b.css ) {
						expect( href.startsWith( "/includes/build/" ) ).toBeTrue( "css href '#href#' should be un-prefixed" );
					}
					for ( var href in b.preload ) {
						expect( href.startsWith( "/includes/build/" ) ).toBeTrue( "preload href '#href#' should be un-prefixed" );
					}
				} );

				it( "prod, moduleRoot='' (root app): no double slashes; equals buildPath + file", function(){
					var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" }, "" );
					var p = d.path( "resources/js/app.js" );
					expect( p ).toBe( "/includes/build/assets/app-abc123.js" );
					expect( p ).notToInclude( "//" );
				} );

				it( "prod, CSS-only entry, mounted module: prefix is applied to the css entry file too", function(){
					var d = buildDriver( { manifestPath : "/resources/vite/manifest-css-only-entry.json" }, "/tests" );
					var b = d.bundle( "resources/scss/app.scss" );
					expect( b.js ).toBe( "" );
					expect( b.css ).notToBeEmpty();
					expect( b.css[ 1 ] ).toBe( "/tests/includes/build/assets/styles-DjqQenkQ.css" );
				} );

				it( "dev (isHot=true), mounted module: URLs stay the absolute dev-server URLs, un-prefixed", function(){
					var d = buildDriver(
						{
							manifestPath : "/resources/vite/manifest-with-imports.json",
							hotFilePath  : "/resources/vite/hot",
							devMode      : true
						},
						"/tests"
					);
					expect( d.isHot() ).toBeTrue();
					expect( d.path( "resources/js/app.js" ) ).toBe( "http://127.0.0.1:5173/resources/js/app.js" );
					expect( d.bundle( "resources/js/app.js" ).js ).toBe( "http://127.0.0.1:5173/resources/js/app.js" );
				} );

				it( "prod, mounted module: explicit prependModuleRoot=true prefixes the same as the default", function(){
					var d = buildDriver(
						{
							manifestPath      : "/resources/vite/manifest-with-imports.json",
							prependModuleRoot : true
						},
						"/tests"
					);
					expect( d.path( "resources/js/app.js" ) ).toBe( "/tests/includes/build/assets/app-abc123.js" );
				} );

				it( "prod, mounted module: path() caches the prefixed URL — a second call is identical (no double prefix)", function(){
					var d = buildDriver( { manifestPath : "/resources/vite/manifest-with-imports.json" }, "/tests" );
					var first  = d.path( "resources/js/app.js" );
					var second = d.path( "resources/js/app.js" );
					expect( first ).toBe( "/tests/includes/build/assets/app-abc123.js" );
					expect( second ).toBe( first );
				} );

				it( "prod, mounted module: cssTags() and jsTags() emit module-root-prefixed hrefs", function(){
					var d = buildDriver( { manifestPath : "/resources/vite/manifest-with-imports.json" }, "/tests" );

					var css = d.cssTags( "resources/js/app.js" );
					expect( css ).toInclude( "href=""/tests/includes/build/assets/app-abc123.css""" );

					var js = d.jsTags( "resources/js/app.js" );
					expect( js ).toInclude( "href=""/tests/includes/build/assets/vendor-def456.js""" );
					expect( js ).toInclude( "src=""/tests/includes/build/assets/app-abc123.js""" );
				} );
			} );

			describe( "critical CSS", function(){
				it( "emits inline #encodeForHtml( "<style>" )# + preload-swap when enabled and a fixture file exists for the event", function(){
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

				it( "throws MalformedCriticalCss when critical file contains #encodeForHtml( "</style>" )#", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( () => d.tags( "resources/js/app.js", { criticalEvent: "bad.injection" } ) )
						.toThrow( type = "MalformedCriticalCss" );
				} );

				it( "criticalSuppressInline=true emits preload-swap CSS without the #encodeForHtml( "<style>" )# block", function(){
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

			describe( "bundle().criticalCss", function(){
				it( "is empty by default (criticalCss.enabled=false)", function(){
					var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
					var b = d.bundle( "resources/js/app.js" );
					expect( b ).toHaveKey( "criticalCss" );
					expect( b.criticalCss ).toBe( "" );
				} );

				it( "carries the inline body when enabled and event has a fixture file", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var b = d.bundle( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( b.criticalCss ).toInclude( ".hero{color:##222" );
				} );

				it( "is empty when the event has no critical file", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var b = d.bundle( "resources/js/app.js", { criticalEvent: "missing.event" } );
					expect( b.criticalCss ).toBe( "" );
				} );

				it( "is empty when options.skipCritical=true even with a fixture present", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var b = d.bundle( "resources/js/app.js", { criticalEvent: "main.index", skipCritical: true } );
					expect( b.criticalCss ).toBe( "" );
				} );

				it( "is empty in dev mode regardless of fixture presence", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						hotFilePath  : "/tests/resources/vite/hot",
						devMode      : true,
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( d.isHot() ).toBeTrue();
					var b = d.bundle( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( b.criticalCss ).toBe( "" );
				} );

				it( "throws MalformedCriticalCss when fixture contains #encodeForHtml( "</style>" )#", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( () => d.bundle( "resources/js/app.js", { criticalEvent: "bad.injection" } ) )
						.toThrow( type = "MalformedCriticalCss" );
				} );

				it( "manifest-derived fields (js/css/preload) remain cached across calls", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var a = d.bundle( "resources/js/app.js", { criticalEvent: "main.index" } );
					var b = d.bundle( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( a.js ).toBe( b.js );
					expect( a.css ).toBe( b.css );
					expect( a.preload ).toBe( b.preload );
					expect( a.criticalCss ).toBe( b.criticalCss );
				} );
			} );

			describe( "cssTags() + jsTags() split", function(){
				it( "cssTags emits stylesheet links and no script in production", function(){
					var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
					var html = d.cssTags( "resources/js/app.js" );
					expect( html ).toInclude( "<link rel=""stylesheet"" href=""/includes/build/assets/app-abc123.css""" );
					expect( html ).notToInclude( "<script" );
					expect( html ).notToInclude( "modulepreload" );
				} );

				it( "jsTags emits modulepreload + entry script and no CSS in production", function(){
					var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
					var html = d.jsTags( "resources/js/app.js" );
					expect( html ).toInclude( "<link rel=""modulepreload"" href=""/includes/build/assets/vendor-def456.js""" );
					expect( html ).toInclude( "<script type=""module"" src=""/includes/build/assets/app-abc123.js""" );
					expect( html ).notToInclude( "rel=""stylesheet""" );
					expect( html ).notToInclude( "<style" );
				} );

				it( "cssTags + jsTags is byte-equivalent to tags() with no critical CSS", function(){
					var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
					var combined = d.cssTags( "resources/js/app.js" ) & d.jsTags( "resources/js/app.js" );
					expect( combined ).toBe( d.tags( "resources/js/app.js" ) );
				} );

				it( "cssTags emits inline #encodeForHtml( "<style>" )# + preload-swap when critical CSS is enabled and file exists", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.cssTags( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( html ).toInclude( "<style>" );
					expect( html ).toInclude( ".hero{color:##222" );
					expect( html ).toInclude( "rel=""preload""" );
					expect( html ).toInclude( "as=""style""" );
					// no JS in CSS slice
					expect( html ).notToInclude( "<script" );
					expect( html ).notToInclude( "modulepreload" );
				} );

				it( "cssTags + jsTags is byte-equivalent to tags() with critical CSS enabled + file present", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var combined = d.cssTags( "resources/js/app.js", { criticalEvent: "main.index" } )
						& d.jsTags( "resources/js/app.js", { criticalEvent: "main.index" } );
					expect( combined ).toBe( d.tags( "resources/js/app.js", { criticalEvent: "main.index" } ) );
				} );

				it( "cssTags + jsTags is byte-equivalent to tags() when critical enabled but file missing", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var combined = d.cssTags( "resources/js/app.js", { criticalEvent: "missing.event" } )
						& d.jsTags( "resources/js/app.js", { criticalEvent: "missing.event" } );
					expect( combined ).toBe( d.tags( "resources/js/app.js", { criticalEvent: "missing.event" } ) );
				} );

				it( "cssTags returns '' in dev mode (Vite injects CSS via the entry script)", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						hotFilePath  : "/tests/resources/vite/hot",
						devMode      : true
					} );
					expect( d.isHot() ).toBeTrue();
					expect( d.cssTags( "resources/js/app.js" ) ).toBe( "" );
				} );

				it( "jsTags returns the dev-server script in dev mode", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						hotFilePath  : "/tests/resources/vite/hot",
						devMode      : true
					} );
					var html = d.jsTags( "resources/js/app.js" );
					expect( html ).toInclude( "src=""http://127.0.0.1:5173/resources/js/app.js""" );
					expect( html ).notToInclude( "<link rel" );
				} );

				it( "cssTags suppresses the inline #encodeForHtml( "<style>" )# when criticalSuppressInline=true (preload-swap still emitted)", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					var html = d.cssTags( "resources/js/app.js", {
						criticalEvent          : "main.index",
						criticalSuppressInline : true
					} );
					expect( html ).notToInclude( "<style>" );
					expect( html ).toInclude( "rel=""preload""" );
					expect( html ).toInclude( "as=""style""" );
				} );

				it( "jsTags applies extra attributes to the entry script", function(){
					var d = buildDriver( { manifestPath : "/tests/resources/vite/manifest-with-imports.json" } );
					var html = d.jsTags( "resources/js/app.js", { attributes: { defer: true } } );
					expect( html ).toInclude( "defer" );
				} );
			} );

			describe( "criticalCss(options) driver method", function(){
				it( "returns the inline body for the resolved event when enabled", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( d.criticalCss( { criticalEvent: "main.index" } ) ).toInclude( ".hero{color:##222" );
				} );

				it( "returns '' when skipCritical=true", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( d.criticalCss( { criticalEvent: "main.index", skipCritical: true } ) ).toBe( "" );
				} );

				it( "returns '' when no event is provided", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-with-imports.json",
						criticalCss  : { enabled: true, path: "/tests/resources/critical", suffix: ".critical.css" }
					} );
					expect( d.criticalCss() ).toBe( "" );
				} );
			} );

			describe( "CSS-only entry via tags()", function(){
				it( "prod: tags() decorates the stylesheet #encodeForHtml( "<link>" )# with attributes (entry has no script)", function(){
					var d    = buildDriver( { manifestPath : "/tests/resources/vite/manifest-css-only-entry.json" } );
					var html = d.tags( "resources/scss/app.scss", { attributes: { "data-foo": true } } );
					expect( html ).toInclude( "<link rel=""stylesheet"" href=""/includes/build/assets/styles-DjqQenkQ.css""" );
					expect( html ).toInclude( "data-foo" );
					expect( html ).notToInclude( "<script" );
				} );

				it( "dev: tags() emits the dev-server module script for the .scss entry", function(){
					var d = buildDriver( {
						manifestPath : "/tests/resources/vite/manifest-css-only-entry.json",
						hotFilePath  : "/tests/resources/vite/hot",
						devMode      : true
					} );
					expect( d.isHot() ).toBeTrue();
					var html = d.tags( "resources/scss/app.scss" );
					expect( html ).toInclude( "<script type=""module"" src=""http://127.0.0.1:5173/resources/scss/app.scss""" );
					expect( html ).notToInclude( "<link rel" );
				} );
			} );
		} );
	}

}
