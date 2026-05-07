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
				devMode : false,
				cache   : { enabled : true, devCheckInterval : 2000 }
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
		} );
	}

}
