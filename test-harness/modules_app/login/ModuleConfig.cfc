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
        // Note: We are using the default Coldbox elixir convention for Mixr
		variables.settings = {};

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
