component {

	// Module Properties
	this.title 				= "login";
	this.author 			= "";
	this.webURL 			= "";
	this.description 		= "";
	this.version			= "1.0.0";
	// If true, looks for views in the parent first, if not found, then in the module. Else vice-versa
	this.viewParentLookup 	= true;
	// If true, looks for layouts in the parent first, if not found, then in module. Else vice-versa
	this.layoutParentLookup = true;
	// Module Entry Point
	this.entryPoint			= "login";
	// Inheritable entry point.
	this.inheritEntryPoint 	= true;
	// Model Namespace
	this.modelNamespace		= "login";
	// CF Mapping
	this.cfmapping			= "login";
	// Auto-map models
	this.autoMapModels		= true;
	// Module Dependencies
    this.dependencies 		= [];

	function configure(){

		// module settings - stored in modules.name.settings
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
