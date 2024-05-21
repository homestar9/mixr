<cfoutput>
    <h2>Mixr Tests</h2>

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