component extends="coldbox.system.testing.BaseModelTest" {

	function beforeAll() {
		super.beforeAll();
		variables.store    = createObject( "component", "mixr.models.support.ManifestStore" ).init();
		variables.renderer = createObject( "component", "mixr.models.support.TagRenderer" ).init();
		variables.watcher  = createObject( "component", "mixr.models.support.HotFileWatcher" ).init();
	}

	function buildDriver( required struct settings ) {
		structAppend(
			arguments.settings,
			{
				devMode             : false,
				renderModulePreload : true,
				includeImportedCss  : true,
				devServerUrl        : "",
				hotFilePath         : "/tests/resources/vite/__no_hot__",
				buildPath           : "/includes/build",
				cache               : { enabled: true, devCheckInterval: 2000 }
			},
			false
		);
		var d = createObject( "component", "mixr.models.drivers.ViteDriver" );
		return d.init(
			settings   = arguments.settings,
			moduleRoot = "",
			store      = variables.store,
			watcher    = variables.watcher,
			renderer   = variables.renderer
		);
	}

	function run() {
		describe( "ViteDriver", function() {

			it( "resolves a production entry to its built file under buildPath", function() {
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json"
				} );
				expect( d.path( "resources/js/app.js" ) )
					.toBe( "/includes/build/assets/app-abc123.js" );
			} );

			it( "throws EntryNotFound for unknown entry", function() {
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json"
				} );
				expect( () => d.path( "resources/js/missing.js" ) )
					.toThrow( type = "EntryNotFound" );
			} );

			it( "throws MalformedManifest for invalid JSON", function() {
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-malformed.json"
				} );
				expect( () => d.path( "anything" ) )
					.toThrow( type = "MalformedManifest" );
			} );

			it( "aggregates CSS from entry and recursively imported chunks", function() {
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json"
				} );
				var b = d.bundle( "resources/js/app.js" );
				expect( b.css ).toHaveLength( 3 );
				expect( b.css[ 1 ] ).toInclude( "app-abc123.css" );
				expect( b.css[ 2 ] ).toInclude( "vendor-def456.css" );
				expect( b.css[ 3 ] ).toInclude( "shared-ghi789.css" );
			} );

			it( "skips imported CSS when includeImportedCss is false", function() {
				var d = buildDriver( {
					manifestPath       : "/tests/resources/vite/manifest-with-imports.json",
					includeImportedCss : false
				} );
				var b = d.bundle( "resources/js/app.js" );
				expect( b.css ).toHaveLength( 1 );
				expect( b.css[ 1 ] ).toInclude( "app-abc123.css" );
			} );

			it( "produces modulepreload list of imported chunk JS", function() {
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json"
				} );
				var b = d.bundle( "resources/js/app.js" );
				expect( b.preload ).toHaveLength( 2 );
				expect( b.preload[ 1 ] ).toInclude( "vendor-def456.js" );
				expect( b.preload[ 2 ] ).toInclude( "shared-ghi789.js" );
			} );

			it( "omits modulepreload list when renderModulePreload=false", function() {
				var d = buildDriver( {
					manifestPath        : "/tests/resources/vite/manifest-with-imports.json",
					renderModulePreload : false
				} );
				var b = d.bundle( "resources/js/app.js" );
				expect( b.preload ).toBeEmpty();
			} );

			it( "renders production HTML tags with css, preload, and module script", function() {
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json"
				} );
				var html = d.tags( "resources/js/app.js" );
				expect( html ).toInclude( '<link rel="stylesheet" href="/includes/build/assets/app-abc123.css"' );
				expect( html ).toInclude( '<link rel="modulepreload" href="/includes/build/assets/vendor-def456.js"' );
				expect( html ).toInclude( '<script type="module" src="/includes/build/assets/app-abc123.js"' );
			} );

			it( "renders dev-server tag when hot file is present", function() {
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json",
					hotFilePath  : "/tests/resources/vite/hot",
					devMode      : true
				} );
				expect( d.isHot() ).toBeTrue();
				var html = d.tags( "resources/js/app.js" );
				expect( html ).toInclude( 'src="http://127.0.0.1:5173/resources/js/app.js"' );
				expect( html ).notToInclude( "<link rel" );
			} );

			it( "viteClient() returns @vite/client tag in dev, empty in prod", function() {
				var prod = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json"
				} );
				expect( prod.viteClient() ).toBe( "" );

				var dev = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json",
					hotFilePath  : "/tests/resources/vite/hot",
					devMode      : true
				} );
				expect( dev.viteClient() ).toInclude( "/@vite/client" );
			} );

			it( "caches bundle results between calls", function() {
				var d = buildDriver( {
					manifestPath : "/tests/resources/vite/manifest-with-imports.json"
				} );
				var a = d.bundle( "resources/js/app.js" );
				var b = d.bundle( "resources/js/app.js" );
				expect( a ).toBe( b );
			} );

		} );
	}

}
