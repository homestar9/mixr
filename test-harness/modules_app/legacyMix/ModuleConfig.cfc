component {

	// Module Properties
	this.title 				= "legacyMix";
	this.author 			= "";
	this.webURL 			= "";
	this.description 		= "";
	this.version			= "1.0.0";

	// Module Entry Point
	this.entryPoint			= "/legacyMix";
	// Model Namespace
	this.modelNamespace		= "legacyMix";
	// CF Mapping
	this.cfmapping			= "legacyMix";

	// Module Dependencies
	this.dependencies 		= [];

	function configure(){

		// Simulates a 2.x app that upgraded to 3.0 and relied on the OLD
		// default manifestPath: it declares driver "auto" but never sets
		// manifestPath, and ships no Vite manifest and no hot file. Mixr's
		// auto-detection must therefore throw a ManifestNotFound whose detail
		// names the 2.x migration fix (set manifestPath explicitly). There is
		// deliberately no silent legacy-path fallback.
		variables.settings = {
			mixr = {
				"driver" : "auto"
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
