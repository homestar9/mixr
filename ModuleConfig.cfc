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
	this.description 		= "ColdBox asset helper for Vite, Laravel Mix, ColdBox Elixir, and custom manifest bundlers";
	this.version 			= "3.0.0";

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
	 *
	 * Mixr's system defaults are declared in a single place:
	 * `models/Mixr.cfc systemDefaults()`. They are merged in at runtime by
	 * `effectiveSettings()`, so any keys the host (or a submodule) does not
	 * specify will fall through to those defaults — there is no need to
	 * mirror them here.
	 *
	 * Settings do NOT cascade between modules. See `models/Mixr.cfc`
	 * `effectiveSettings()` for the resolution chain.
	 */
	function configure(){
		variables.settings = {};
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
