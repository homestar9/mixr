/**
 * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
 */
component {

	// Module Properties
	this.title 				= "mixr";
	this.author 			= "Angry Sam Productions, Inc.";
	this.webURL 			= "https://github.com/homestar9/mixr";
	this.description 		= "Returns the mix'd path of a public asset from a manifest file";
	this.version 			= "1.0.0";

	// Model Namespace
	this.modelNamespace		= "mixr";

	// CF Mapping
	this.cfmapping			= "mixr";

	// Dependencies
	this.dependencies 		= [];

    // Application helper
    this.applicationHelper 	= [ "helpers/Mixins.cfm" ];

	/**
	 * Configure Module
	 */
	function configure(){
		settings = {
            "manifestPath" = "/includes/rev-manifest.json",
            "prependModuleRoot" = true,
            "prependPath" = "",
            "modules": {}
		};
	}

	/**
	 * Fired when the module is registered and activated.
	 */
	function onLoad(){
        binder.map( "Mixr@mixr" ).to( "#moduleMapping#.models.Mixr" );
	}

	/**
	 * Fired when the module is unregistered and unloaded
	 */
	function onUnload(){

	}

}
