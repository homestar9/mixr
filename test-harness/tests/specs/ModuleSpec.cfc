component extends="coldbox.system.testing.BaseModelTest" model="mixr.models.Mixr" {

	variables._settings = {
        "manifestPath": "/tests/resources/rev-manifest.json",
        "prependModuleRoot": false,
        "prependPath": "",
        "modules": {
            "fooModule": {
                "manifestPath": "/public/mix-manifest.json",
                "prependModuleRoot": true
            }
        }
    }
    
    /*********************************** LIFE CYCLE Methods ***********************************/

	function beforeAll(){
		super.beforeAll();
		setup();

        // mock properties
        model.$property( "settings", "variables", variables._settings );

        model = model.init();
		
	}

	function afterAll(){
		super.afterAll();
	}

	/*********************************** BDD SUITES ***********************************/

	function run(){
		describe( "Mixr", function(){
			beforeEach( function( currentSpec ){
			} );

            it( "can be created", function(){
                expect( model ).toBeComponent();
            });

            
            it( "Can return an asset from a manifest file", function(){
                var result = model.get( "/tests/asset.js" );
                expect( result ).toBe( "/tests/asset.123456.js" );
            });

            it( "Can return an asset from a custom manfest path", function(){
                var result = model.get(
                    asset = "/tests/asset.js",
                    manifestPath = "/tests/resources/public/custom-manifest.json"
                );
                expect( result ).toBe( "/tests/asset.abcdefg.js" );
            } );

            it( "Can append the module path to the output", function(){
                var result = model.get(
                    asset = "css/foo.css",
                    moduleName = "fooModule",
                    moduleRoot = "/modules/fooModule/",
                    prependModuleRoot = true
                );
                debug( result );
                expect( result ).toBe( "/modules/fooModule/css/foo.28fc241b1431baefb2a9b4307ed9cff1.css" );
            } );

		} );
	}

}
