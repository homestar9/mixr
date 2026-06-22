component extends="coldbox.system.testing.BaseTestCase" appMapping="/" {

	function beforeAll(){
		super.beforeAll();
		setup();
		variables.wirebox  = getController().getWireBox();
		variables.store    = wirebox.getInstance( "ManifestStore@mixr" );
		variables.renderer = wirebox.getInstance( "TagRenderer@mixr" );
		variables.watcher  = wirebox.getInstance( "HotFileWatcher@mixr" );
	}

	function buildVite( required string manifestPath ){
		var settings = {
			manifestPath        : arguments.manifestPath,
			devMode             : false,
			renderModulePreload : true,
			includeImportedCss  : true,
			devServerUrl        : "",
			hotFilePath         : "/tests/resources/vite/__no_hot__",
			buildPath           : "/includes/build",
			prependModuleRoot   : false,
			cache               : { enabled : true, devCheckInterval : 2000 },
			criticalCss         : { enabled : false, path : "/tests/resources/critical", suffix : ".critical.css" }
		};
		return wirebox.getInstance(
			name          = "ViteDriver@mixr",
			initArguments = { settings : settings, moduleRoot : "", store : store, watcher : watcher, renderer : renderer }
		);
	}

	function buildManifest( required string manifestPath ){
		var settings = {
			manifestPath      : arguments.manifestPath,
			devMode           : false,
			prependModuleRoot : false,
			prependPath       : "",
			cache             : { enabled : true, devCheckInterval : 2000 },
			criticalCss       : { enabled : false, path : "/tests/resources/critical", suffix : ".critical.css" }
		};
		return wirebox.getInstance(
			name          = "ManifestDriver@mixr",
			initArguments = { settings : settings, moduleRoot : "", store : store, watcher : watcher, renderer : renderer }
		);
	}

	function run(){
		// Guarantees attribute PLACEMENT parity across drivers for an app that
		// switches between a Vite manifest and a flat (Webpack/Mix/Elixir)
		// manifest with the same mixr().tags( entry, { attributes } ) call.
		// The full tag strings differ by design (Vite uses hashed buildPath
		// URLs + type="module" + extra graph-derived CSS/modulepreload links;
		// the flat manifest emits one query-versioned tag) — but the attribute
		// always lands on the same LOGICAL tag: the <script> for a JS entry,
		// the stylesheet <link> for a CSS entry.
		describe( "cross-driver attribute placement (Vite vs flat manifest)", function(){
			it( "JS entry: `defer` lands on the entry #encodeForHtml( "<script>" )# in BOTH drivers", function(){
				var vite     = buildVite( "/tests/resources/vite/manifest-with-imports.json" );
				var manifest = buildManifest( "/tests/resources/mix-manifest.json" );

				var vHtml = vite.tags( "resources/js/app.js", { attributes : { defer : true } } );
				var mHtml = manifest.tags( "/js/app.js", { attributes : { defer : true } } );

				// `defer` is the script's trailing attribute in both → proves it's on the <script>
				expect( vHtml ).toInclude( "defer></script>" );
				expect( mHtml ).toInclude( "defer></script>" );

				// Vite's imported CSS links stay bare (attribute is NOT smeared across them)
				expect( vHtml ).toInclude( "<link rel=""stylesheet"" href=""/includes/build/assets/app-abc123.css"" />" );
			} );

			it( "CSS entry: `data-x` lands on the stylesheet #encodeForHtml( "<link>" )# in BOTH drivers", function(){
				var vite     = buildVite( "/tests/resources/vite/manifest-css-only-entry.json" );
				var manifest = buildManifest( "/tests/resources/mix-manifest.json" );

				var vHtml = vite.tags( "resources/scss/app.scss", { attributes : { "data-x" : "y" } } );
				var mHtml = manifest.tags( "/css/app.css", { attributes : { "data-x" : "y" } } );

				// both emit a single stylesheet <link> carrying the attribute, no <script>
				expect( vHtml ).toInclude( "rel=""stylesheet""" );
				expect( vHtml ).toInclude( "data-x=""y""" );
				expect( vHtml ).notToInclude( "<script" );

				expect( mHtml ).toInclude( "rel=""stylesheet""" );
				expect( mHtml ).toInclude( "data-x=""y""" );
				expect( mHtml ).notToInclude( "<script" );
			} );
		} );
	}

}
