component{

	// Configure ColdBox Application
	function configure(){

		// coldbox directives
		coldbox = {
			//Application Setup
			appName 				= "Module Tester",

			//Development Settings
			reinitPassword			= "",
			handlersIndexAutoReload = true,
			modulesExternalLocation = [],

			//Implicit Events
			defaultEvent			= "",
			requestStartHandler		= "",
			requestEndHandler		= "",
			applicationStartHandler = "",
			applicationEndHandler	= "",
			sessionStartHandler 	= "",
			sessionEndHandler		= "",
			missingTemplateHandler	= "",

			//Error/Exception Handling
			exceptionHandler		= "",
			onInvalidEvent			= "",
			customErrorTemplate 	= "/coldbox/system/exceptions/Whoops.cfm",

			//Application Aspects
			handlerCaching 			= false,
			eventCaching			= false
		};

		// environment settings, create a detectEnvironment() method to detect it yourself.
		// create a function with the name of the environment so it can be executed if that environment is detected
		// the value of the environment is a list of regex patterns to match the cgi.http_host.
		environments = {
			development = "localhost,127\.0\.0\.1"
		};

		// Module Directives
		modules = {
			// An array of modules names to load, empty means all of them
			include = [],
			// An array of modules names to NOT load, empty means none
			exclude = []
		};

		//Register interceptors as an array, we need order
		interceptors = [
		];

		//LogBox DSL
		logBox = {
			// Define Appenders
			appenders = {
				myConsole : { class : "ConsoleAppender" },
				files : {
					class="RollingFileAppender",
					properties = {
						filename = "tester", filePath="/#appMapping#/logs"
					}
				}
			},
			// Root Logger
			root = { levelmax="DEBUG", appenders="*" },
			// Implicit Level Categories
			info = [ "coldbox.system" ]
		};

        moduleSettings = {
            mixr = {
                // Harness root simulates a Laravel Mix app
                "driver"            : "manifest",
                "manifestPath"      : "/tests/resources/mix-manifest.json",
                "prependModuleRoot" : false,
                "prependPath"       : "",
                "modules": {
                    "fooModule": {
                        "driver"            : "manifest",
                        "manifestPath"      : "/public/mix-manifest.json",
                        "prependModuleRoot" : true,
                        "prependPath"       : "/includes"
                    }
                }
            }
        }

	}

	/**
	 * Load the Module you are testing
	 */
	function afterAspectsLoad( event, interceptData, rc, prc ){

		controller.getModuleService()
			.registerAndActivateModule(
				moduleName 		= request.MODULE_NAME,
				invocationPath 	= "moduleroot"
			);

		// IMPORTANT: this harness registers the module-under-test from
		// `afterAspectsLoad`, which fires AFTER `Renderer.startup()` has
		// already loaded the global `applicationHelper` list into the
		// singleton renderer's variables scope (see
		// coldbox/system/web/services/LoaderService.cfc lines 88-102).
		// Because of that ordering, mixr's `helpers/Mixins.cfm` is added
		// to the setting too late for the renderer to ever pick it up,
		// and views fail with "No matching function [MIXR]" while
		// handlers work fine (handlers re-load helpers per request via
		// onHandlerDIComplete). Real apps don't hit this because they
		// load mixr via convention-based discovery during
		// `activateAllModules()` BEFORE `Renderer.startup()` runs.
		// Force the renderer to re-inject helpers so the harness can
		// exercise view-side `mixr()` calls. This belongs in the harness,
		// not in the module.
		controller.getRenderer().loadApplicationHelpers( force = true );
	}

}
