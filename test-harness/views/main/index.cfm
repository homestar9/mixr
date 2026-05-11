<cfoutput>
    
    <h2>Mixr 3.0 Fluent Chains</h2>

    <!--- path() — single resolved URL string --->
    <div>
        #mixr().path( "/css/app.css" )#
    </div>
    <!--- bundle() — { js, css[], preload[], criticalCss } --->
    <div>
        <cfdump var="#mixr().bundle( "/css/app.css" )#">
    </div>
    <!--- criticalCss() — just the inline CSS body for the current event --->
    <cfset critical = mixr().criticalCss()>
    <cfif len( critical )>
        <style>#critical#</style>
    </cfif>
    <!--- tags() — fully-rendered HTML --->
    <div>
        #mixr().tags( "/js/app.js" )#
    </div>

    <h2>Legacy Mixr 2.0 Tests</h2>

    <!--- Assets in this module --->
    <div>
        #mixr( "/css/app.css" )#
    </div>
    <div>
        #mixr( "/js/app.js" )#
    </div>

    <!--- Assets in a tracked submodule --->
    <div>
        #mixr( "/css/login.css", "login" )#
    </div>
    <!--- Assets in a tracked submodule --->
    <div>
        #mixr( "/js/login.js", "login" )#
    </div>

    <!--- Assets in a submodule that use a different convention --->
    <div>
        #mixr( "css/foo.css", "fooModule", "public/mix-manifest.json" )#
    </div>
    <div>
        #mixr( "js/foo.js", "fooModule", "public/mix-manifest.json" )#
    </div>

    <!--- Assets in a submodule that use the moduleconfig to set convention (Coldbox Elixir convention) --->
    <div>
        #mixr( "includes/js/elixir.js", "elixir" )#
    </div>
    <div>
        #mixr( "includes/css/elixir.css", "elixir" )#
    </div>





</cfoutput>