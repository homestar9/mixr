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
		// inside this module's includes folder.
		variables.settings = {
			mixr: {
				"driver"       : "vite",
				"manifestPath" : "/includes/build/.vite/manifest.json",
				"buildPath"    : "/includes/build",
				"hotFilePath"  : "/includes/hot"
			}
		};

	}

	function onLoad(){}
	function onUnload(){}

}
