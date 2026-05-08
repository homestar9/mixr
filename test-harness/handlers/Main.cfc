/**
* My Event Handler Hint
*/
component{

	/**
     * Default endpoint — renders a view that exercises the global mixr() helper in various forms.
     * 
     * @event - event
     * @rc - request collection
     * @prc - private request collection
     */
	function index( event, rc, prc ){
		event.setView( "main/index" );
	}

    /**
     * Test endpoint — exercises every shape of the global mixr() helper in a
     * single handler action. Keeping these in one execute() avoids a TestBox
     * + Adobe 2021 incompatibility where multiple execute() calls in the same
     * suite regenerate stub CFMs with the same hash.
     * 
     * @event - event
     * @rc - request collection
     * @prc - private request collection
     */
	function mixrHelperAllShapes( event, rc, prc ) {
		prc.mixrCurrent         = mixr( "/tests/asset.js" );
		prc.mixrOtherLegacy     = mixr( asset = "resources/js/app.js", moduleName = "vite" );
		prc.mixrOtherFluent     = mixr( moduleName = "vite" ).path( "resources/js/app.js" );
		prc.mixrCurrentFluent   = mixr().path( "/tests/asset.js" );
		// Critical CSS goes through tags() (the fluent form), not the legacy
		// mixr(asset, moduleName) form — that one only resolves a path string.
		prc.mixrCssWithCritical = mixr().tags( "/css/app.css", { criticalEvent: "main.index" } );
	}

}