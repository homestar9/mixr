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
	 * The values declared here are the **system defaults**. Each module
	 * (the root app or any submodule) sees these as its starting point
	 * before its own settings (and any host overrides via `modules.<name>`)
	 * are layered on. Settings do NOT cascade between modules — see
	 * `models/Mixr.cfc` `effectiveSettings()` for the resolution chain.
	 */
	function configure(){
		variables.settings = {
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

			// Critical CSS (above-the-fold inlining)
			//   When enabled, tags() inlines the route's critical CSS file
			//   as a <style> block and async-loads the full CSS via
			//   preload+onload swap (with <noscript> fallback).
			//   Always skipped when isHot() — preview locally with `npm run prod`.
			"criticalCss" : {
				"enabled" : false,                 // OPT-IN
				"path"    : "/includes/critical",  // module-relative directory
				"suffix"  : ".critical.css"        // appended to event name
			},

			"modules" : {}
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
