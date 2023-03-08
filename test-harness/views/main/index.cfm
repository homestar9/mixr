<cfoutput>
    <h2>Mixr Tests</h2>

    <!--- Assets in this module --->
    <div>
        #mixr( "includes/css/app.css" )#
    </div>
    <div>
        #mixr( "includes/js/app.js" )#
    </div>

    <!--- Assets in a tracked submodule --->
    <div>
        #mixr( "includes/css/login.css", "login" )#
    </div>
    <!--- Assets in a tracked submodule --->
    <div>
        #mixr( "includes/js/login.js", "login" )#
    </div>

    <!--- Assets in a submodule that use a different convention --->
    <div>
        #mixr( "css/foo.css", "fooModule", "public/mix-manifest.json" )#
    </div>
    <div>
        #mixr( "js/foo.js", "fooModule", "public/mix-manifest.json" )#
    </div>

    

    <h2>ElixirPath Tests</h2>

    <div>
        #html.elixirPath( "includes/css/app.css" )#
    </div>
    <div>
        #html.elixirPath( "includes/js/app.js" )#
    </div>

    <!--- Assets in a tracked submodule --->
    <div>
        #html.elixirPath( 
            fileName = "includes/css/login.css", 
            manifestRoot = "modules_app/login/includes/" 
        )#
    </div>

    <div>
        #html.elixirPath( 
            fileName = "includes/js/login.js", 
            manifestRoot = "modules_app/login/includes/" 
        )#
    </div>

    <h2>Performance Tests</h2>

    <cfset iterations = "1000">

    <h3>Mixr</h3>

    <cfset start = getTickCount() />

    <cfloop from="1" to="#iterations#" index="a">
        <cfset asset1 = mixr( "includes/css/app.css" ) />
        <cfset asset2 = mixr( "includes/js/app.js" ) />
        <cfset asset3 = mixr( "includes/css/login.css", "login" ) />
        <cfset asset4 = mixr( "includes/js/login.js", "login" ) />
    </cfloop>

    <p>Time: #getTickCount() - start#ms</p>

    <h3>ElixirPath</h3>
    
    <cfset start = getTickCount() />

    <cfloop from="1" to="#iterations#" index="a">
        <cfset asset1 = html.elixirPath( "includes/css/app.css" ) />
        <cfset asset2 = html.elixirPath( "includes/js/app.js" ) />
        <cfset asset3 = html.elixirPath( 
            fileName = "includes/css/login.css", 
            manifestRoot = "modules_app/login/includes/" 
        ) />
        <cfset asset4 = html.elixirPath( 
            fileName = "includes/js/login.js", 
            manifestRoot = "modules_app/login/includes/" 
        ) />
    </cfloop>

    <p>Time: #getTickCount() - start#ms</p>


</cfoutput>