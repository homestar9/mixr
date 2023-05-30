component {

	// Module Properties
	this.title 				= "fooModule";
	this.author 			= "";
	this.webURL 			= "";
	this.description 		= "";
	this.version			= "1.0.0";
	// If true, looks for views in the parent first, if not found, then in the module. Else vice-versa
	this.viewParentLookup 	= true;
	// If true, looks for layouts in the parent first, if not found, then in module. Else vice-versa
	this.layoutParentLookup = true;
	// Module Entry Point
	this.entryPoint			= "fooModule";
	// Inheritable entry point.
	this.inheritEntryPoint 	= true;
	// Model Namespace
	this.modelNamespace		= "fooModule";
	// CF Mapping
	this.cfmapping			= "fooModule";
	// Auto-map models
	this.autoMapModels		= true;
	// Module Dependencies
    this.dependencies 		= [];

	function configure(){


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
