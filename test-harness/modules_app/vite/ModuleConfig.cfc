component {

	this.title 				= "vite";
	this.author 			= "";
	this.webURL 			= "";
	this.description 		= "Vite production-style module fixture";
	this.version			= "1.0.0";

	this.entryPoint			= "/vite";
	this.modelNamespace		= "vite";
	this.cfmapping			= "vite";
	this.dependencies 		= [];

	function configure(){

		// Override mixr to use the explicit Vite driver and a manifest located
		// inside this module's includes folder. Critical CSS is opted-in for
		// integration-test purposes; a fixture file lives at
		// /includes/critical/main.index.critical.css.
		variables.settings = {
			mixr: {
				"driver"       : "vite",
				"manifestPath" : "/includes/build/.vite/manifest.json",
				"buildPath"    : "/includes/build",
				"hotFilePath"  : "/includes/hot",
				"criticalCss"  : { "enabled" : true }
			}
		};

	}

	function onLoad(){}
	function onUnload(){}

}
