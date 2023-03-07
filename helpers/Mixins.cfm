<cfscript>

    /**
     * mixr
     * Allows mixr() to be available in all handlers/views for easy access
     * 
     * @path the path to the asset as it exists in the manifest file
     * @moduleName the name of the module
     * @manifestPath override path of the manifest file
     */ 
    function mixr( 
        required string path, 
        string moduleName = controller.getRequestService().getContext().getCurrentModule(),
        string manifestPath,
        boolean prependModuleRoot,
        string prependPath
    ) {
        
        arguments.moduleRoot = controller.getRequestService().getContext().getModuleRoot( moduleName );
        
        return wirebox.getInstance( "Mixr@mixr" ).get(
            argumentCollection = arguments
        );

        /* var moduleRoot = controller.getRequestService().getContext().getModuleRoot( moduleName );
        arguments.manifestPath = ( arguments.keyExists( "manifestPath" ) ? arguments.manifestPath : "/includes/rev-manifest.json" );
        arguments.manifestPath = reReplace( arguments.manifestPath, "/^\/+/", '' );

        
        return wirebox.getInstance( "Mixr@mixr" ).get(
            path = arguments.path,
            moduleRoot =
            manifestPath = moduleRoot & "/" & arguments.manifestPath
        ); */
    }

</cfscript>