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
	 */
	function configure(){
		settings = {
			// "vite" | "manifest" | "auto"
			"driver"              : "auto",

			// Vite (and auto-detection) defaults
			"manifestPath"        : "/includes/build/.vite/manifest.json",
			"buildPath"           : "/includes/build",
			"hotFilePath"         : "/includes/hot",
			"devServerUrl"        : "",
			"devMode"             : false,
			"renderModulePreload" : true,
			"includeImportedCss"  : true,

			// Manifest driver (Mix / Elixir / custom) — preserved from 2.x
			"prependModuleRoot"   : true,
			"prependPath"         : "/includes",

			// Caching
			//   devCheckInterval semantics (only used when devMode=true):
			//     0  -> recheck on every request
			//     N  -> throttle rechecks to once per N ms
			//    -1  -> never recheck (treat dev like prod)
			"cache" : {
				"enabled"          : true,
				"devCheckInterval" : 2000
			},

			"modules" : {}
		};
	}

	/**
	 * Fired when the module is registered and activated.
	 */
	function onLoad(){
        binder.map( "Mixr@mixr" ).to( "#moduleMapping#.models.Mixr" );
        binder.map( "MixrScope@mixr" ).to( "#moduleMapping#.models.MixrScope" );
        binder.map( "ManifestStore@mixr" ).to( "#moduleMapping#.models.support.ManifestStore" );
        binder.map( "HotFileWatcher@mixr" ).to( "#moduleMapping#.models.support.HotFileWatcher" );
        binder.map( "TagRenderer@mixr" ).to( "#moduleMapping#.models.support.TagRenderer" );
        binder.map( "ManifestDriver@mixr" ).to( "#moduleMapping#.models.drivers.ManifestDriver" );
        binder.map( "ViteDriver@mixr" ).to( "#moduleMapping#.models.drivers.ViteDriver" );
	}

	/**
	 * Fired when the module is unregistered and unloaded
	 */
	function onUnload(){

	}

}
