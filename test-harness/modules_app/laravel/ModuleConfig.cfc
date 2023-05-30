component {

	// Module Properties
	this.title 				= "laravel";
	this.author 			= "";
	this.webURL 			= "";
	this.description 		= "";
	this.version			= "1.0.0";

	// Module Entry Point
	this.entryPoint			= "/laravel";
	// Model Namespace
	this.modelNamespace		= "laravel";
	// CF Mapping
	this.cfmapping			= "laravel";
	// Auto-map models
	this.autoMapModels		= true;
	// Module Dependencies
    this.dependencies 		= [];

	function configure(){

		layoutSettings = {
            defaultLayout = "Laravel.cfm"
        };
        
        // module settings - stored in modules.name.settings
        // Note: we are overriding mixr conventions in this module
		variables.settings = {
            mixr: {
                "manifestPath": "/includes/mix-manifest.json",
                "prependModuleRoot": true,
                "prependPath": "/includes" 
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
