component extends="coldbox.system.testing.BaseTestCase" appMapping="/" {

	function beforeAll(){
		super.beforeAll();
		setup();
		variables.wirebox = getController().getWireBox();
	}

	function run(){
		describe( "ManifestStore", function(){
			it( "parses a manifest once and caches it", function(){
				var s = wirebox.getInstance( "ManifestStore@mixr" );
				var a = s.get( "/tests/resources/mix-manifest.json" );
				var b = s.get( "/tests/resources/mix-manifest.json" );
				expect( a ).toBe( b );
				expect( a.keyExists( "/tests/asset.js" ) ).toBeTrue();
			} );

			it( "throws ManifestNotFound for missing files", function(){
				var s = wirebox.getInstance( "ManifestStore@mixr" );
				expect( () => s.get( "/tests/resources/__nope__.json" ) ).toThrow( type = "ManifestNotFound" );
			} );

			it( "throws MalformedManifest for invalid JSON", function(){
				var s = wirebox.getInstance( "ManifestStore@mixr" );
				expect( () => s.get( "/tests/resources/vite/manifest-malformed.json" ) ).toThrow(
					type = "MalformedManifest"
				);
			} );

			it( "fires onReload listeners when refresh() is called", function(){
				var s = wirebox.getInstance( "ManifestStore@mixr" );
				s.get( "/tests/resources/mix-manifest.json" );
				var hits = 0;
				s.onReload( "/tests/resources/mix-manifest.json", ( parsed ) => hits++ );
				s.refresh( "/tests/resources/mix-manifest.json" );
				expect( hits ).toBe( 1 );
			} );

			it( "in production mode never re-reads the file", function(){
				var s = wirebox.getInstance( "ManifestStore@mixr" );
				s.get( "/tests/resources/mix-manifest.json", false, 0 );
				// Even with devCheckInterval=0, devMode=false should pin
				var calls = 0;
				s.onReload( "/tests/resources/mix-manifest.json", ( p ) => calls++ );
				for ( var i = 1; i <= 5; i++ ) {
					s.get( "/tests/resources/mix-manifest.json", false, 0 );
				}
				expect( calls ).toBe( 0 );
			} );
		} );
	}

}
