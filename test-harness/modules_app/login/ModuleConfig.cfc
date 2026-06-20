component {

	// Module Properties
	this.title 				= "login";
	this.author 			= "";
	this.webURL 			= "";
	this.description 		= "";
	this.version			= "1.0.0";

	// Module Entry Point
	this.entryPoint			= "/login";
	// Model Namespace
	this.modelNamespace		= "login";
	// CF Mapping
	this.cfmapping			= "login";

	// Module Dependencies
    this.dependencies 		= [];

	function configure(){

		layoutSettings = {
            defaultLayout = "Login.cfm"
        };
        
        // module settings - stored in modules.name.settings
		// Only the manifestPath needs declaring — login uses a Mix-style
		// flat manifest. Everything else (driver auto-detect, prepend
		// behavior) inherits sane system defaults.
		variables.settings = {
			mixr = {
				"manifestPath" : "/includes/mix-manifest.json"
			}
		};

	}

	/**
	* Fired when the module is registered and activated.
	*/
	function onLoad(){

	}

	/**
	* Fired when the module is unregistered and unloaded
	*/
	function onUnload(){

	}

}
