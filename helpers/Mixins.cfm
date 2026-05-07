<cfscript>

    /**
     * mixr() — Mixr 3.0 global helper
     *
     * Three call shapes:
     *
     *   1. Fluent (3.0), current module:
     *        ##mixr().path( "resources/js/app.js" )##
     *        ##mixr().tags( "resources/js/app.js" )##
     *        ##mixr().viteClient()##
     *        ##mixr().isHot()##
     *
     *   2. Fluent (3.0), explicit module — pass moduleName to scope to a
     *      different submodule than the current request:
     *        ##mixr( moduleName = "admin" ).tags( "resources/js/admin.js" )##
     *
     *   3. Legacy (2.x):    ##mixr( "/js/app.js" )##
     *      Returns a single resolved path string. Preserved for backward
     *      compatibility — equivalent to mixr().path( asset ).
     *      You may also pass a moduleName to resolve from another module:
     *        ##mixr( "/js/admin.js", "admin" )##
     *
     * When moduleName is omitted, the active module is auto-detected from
     * the current ColdBox event so submodule configs are picked up
     * automatically.
     */
    function mixr( string asset, string moduleName ) {

        // performance: skip the WireBox lookup on every call
        if ( !variables.keyExists( "mixrService" ) ) {
            variables.mixrService = wirebox.getInstance( "Mixr@mixr" );
        }

        // Default moduleName to whatever module is handling the current request
        var resolvedModule = arguments.keyExists( "moduleName" ) && len( arguments.moduleName )
            ? arguments.moduleName
            : controller.getRequestService().getContext().getCurrentModule();

        // No-asset form → return a module-bound scope for fluent calls
        if ( !arguments.keyExists( "asset" ) || !len( arguments.asset ) ) {
            return variables.mixrService.forModule( resolvedModule );
        }

        // Legacy form → resolved path string
        return variables.mixrService.path( entry = arguments.asset, moduleName = resolvedModule );

    }

</cfscript>