component {

	this.title 				= "viteSpa";
	this.author 			= "";
	this.webURL 			= "";
	this.description 		= "Vite dev-server module fixture (hot file present)";
	this.version			= "1.0.0";

	this.entryPoint			= "/viteSpa";
	this.modelNamespace		= "viteSpa";
	this.cfmapping			= "viteSpa";
	this.dependencies 		= [];

	function configure(){

		variables.settings = {
			mixr: {
				"driver"       : "vite",
				"manifestPath" : "/includes/build/.vite/manifest.json",
				"buildPath"    : "/includes/build",
				"hotFilePath"  : "/includes/hot",
				"devMode"      : true
			}
		};

	}

	function onLoad(){}
	function onUnload(){}

}
