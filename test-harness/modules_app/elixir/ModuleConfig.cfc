component {

	// Module Properties
	this.title 				= "elixir";
	this.author 			= "";
	this.webURL 			= "";
	this.description 		= "";
	this.version			= "1.0.0";

	// Module Entry Point
	this.entryPoint			= "/elixir";
	// Model Namespace
	this.modelNamespace		= "elixir";
	// CF Mapping
	this.cfmapping			= "elixir";
	// Auto-map models
	this.autoMapModels		= true;
	// Module Dependencies
    this.dependencies 		= [];

	function configure(){

		layoutSettings = {
            defaultLayout = "elixir.cfm"
        };
        
        // module settings - stored in modules.name.settings
        // Note: we are overriding mixr conventions in this module
		variables.settings = {
            mixr: {
                "manifestPath": "/includes/rev-manifest.json",
                "prependModuleRoot": true,
                "prependPath": "/" 
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
