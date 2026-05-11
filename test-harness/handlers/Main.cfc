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
     * Resolves an asset for the current module via the legacy string form.
     */
	function mixrCurrent( event, rc, prc ) {
		prc.mixrCurrent = mixr( "/tests/asset.js" );
	}

	/**
	 * Resolves an asset for the current module via the fluent form.
	 */
	function mixrCurrentFluent( event, rc, prc ) {
		prc.mixrCurrentFluent = mixr().path( "/tests/asset.js" );
	}

	/**
	 * Resolves an asset for an explicit module via the legacy form.
	 */
	function mixrOtherLegacy( event, rc, prc ) {
		prc.mixrOtherLegacy = mixr( asset = "resources/js/app.js", moduleName = "vite" );
	}

	/**
	 * Resolves an asset for an explicit module via the fluent form.
	 */
	function mixrOtherFluent( event, rc, prc ) {
		prc.mixrOtherFluent = mixr( moduleName = "vite" ).path( "resources/js/app.js" );
	}

	/**
	 * Renders fluent tags() with critical-CSS options.
	 */
	function mixrCssWithCritical( event, rc, prc ) {
		prc.mixrCssWithCritical = mixr().tags( "/css/app.css", { criticalEvent: "main.index" } );
	}

}