<cfscript>

    /**
     * mixr
     * Allows mixr() to be available in all handlers/views for easy access
     * 
     * @asset the asset as it exists in the manifest file
     * @moduleName the name of the module
     * @manifestPath override path of the manifest file
     * @prependModuleRoot whether to prepend the module root to the resulting path
     * @prependPath
     */ 
    function mixr( 
        required string asset, 
        string moduleName = controller.getRequestService().getContext().getCurrentModule(),
        string manifestPath,
        boolean prependModuleRoot,
        string prependPath
    ) {
        
        // performance: not having to use wirebox every time.
        if ( !variables.keyExists( "mixrService" ) ) {
            variables.mixrService = wirebox.getInstance( "Mixr@mixr" );
        }
    

        return variables.mixrService.get(
            argumentCollection = arguments
        );
    }

</cfscript>