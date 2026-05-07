/**
* My Event Handler Hint
*/
component{

	// Index
	any function index( event,rc, prc ){
		event.setView( "main/index" );
	}

	// Test endpoint — exercises every shape of the global mixr() helper in a
	// single handler action. Keeping these in one execute() avoids a TestBox
	// + Adobe 2021 incompatibility where multiple execute() calls in the same
	// suite regenerate stub CFMs with the same hash.
	any function mixrHelperAllShapes( event, rc, prc ) {
		prc.mixrCurrent       = mixr( "/tests/asset.js" );
		prc.mixrOtherLegacy   = mixr( asset = "resources/js/app.js", moduleName = "vite" );
		prc.mixrOtherFluent   = mixr( moduleName = "vite" ).path( "resources/js/app.js" );
		prc.mixrCurrentFluent = mixr().path( "/tests/asset.js" );
	}

}