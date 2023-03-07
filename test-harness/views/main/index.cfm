<cfoutput>
    <h1>Mixr Tests</h1>

    <cfset start = getTickCount() />

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

    <cfdump var="#getTickCount() - start#" />
</cfoutput>