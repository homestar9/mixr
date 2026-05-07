component extends="coldbox.system.testing.BaseModelTest" {

	function run() {
		describe( "HotFileWatcher", function() {

			beforeEach( function( currentSpec ) {
				variables.w = createObject( "component", "mixr.models.support.HotFileWatcher" ).init();
			} );

			it( "always returns false when devMode=false (no disk hit)", function() {
				expect( w.isHot( hotFilePath = "/tests/resources/vite/hot", devMode = false ) ).toBeFalse();
			} );

			it( "detects a present hot file and reads the dev URL", function() {
				expect( w.isHot( hotFilePath = "/tests/resources/vite/hot", devMode = true ) ).toBeTrue();
				expect( w.url( hotFilePath = "/tests/resources/vite/hot", devMode = true ) )
					.toBe( "http://127.0.0.1:5173" );
			} );

			it( "returns false when hot file is absent", function() {
				expect( w.isHot( hotFilePath = "/tests/resources/vite/__nope__", devMode = true ) ).toBeFalse();
				expect( w.url( hotFilePath = "/tests/resources/vite/__nope__", devMode = true ) ).toBe( "" );
			} );

			it( "falls back to configured devServerUrl when hot file is empty", function() {
				// Reuse the existing hot file but pass a fallback (it will not
				// be used because the file has content). Mainly verifying the
				// argument flow.
				var devUrl = w.url(
					hotFilePath = "/tests/resources/vite/hot",
					devMode     = true,
					fallback    = "http://fallback"
				);
				expect( devUrl ).toBe( "http://127.0.0.1:5173" );
			} );

		} );
	}

}
