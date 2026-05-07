/**
 * MixrScope
 *
 * Lightweight per-module wrapper returned by Mixr.forModule(). Holds a
 * reference to the singleton service and the bound module name, and forwards
 * fluent calls. Allocated once per module name and cached on the service —
 * not per request.
 */
component {

	/**
	 * Constructor. Bind a Mixr service singleton to a single moduleName so
	 * fluent calls don't have to repeat it.
	 *
	 * @service    The Mixr facade singleton.
	 * @moduleName Module name to bind every forwarded call to ("" for root).
	 */
	function init( required any service, required string moduleName ){
		variables.service    = arguments.service;
		variables.moduleName = arguments.moduleName;
		return this;
	}

	/**
	 * Resolve a single asset path through the bound module's driver.
	 *
	 * @entry   Logical entry path (manifest key).
	 * @options Driver-specific overrides; rarely needed.
	 */
	string function path( required string entry, struct options = {} ){
		return variables.service.path(
			entry      = arguments.entry,
			moduleName = variables.moduleName,
			options    = arguments.options
		);
	}

	/**
	 * Render the full HTML tag set for an entry through the bound module's driver.
	 *
	 * @entry   Logical entry path.
	 * @options Optional struct: { as, attributes, renderModulePreload, includeImportedCss }.
	 */
	string function tags( required string entry, struct options = {} ){
		return variables.service.tags(
			entry      = arguments.entry,
			moduleName = variables.moduleName,
			options    = arguments.options
		);
	}

	/**
	 * Render <script type="module" src=".../@vite/client"></script> for the
	 * bound module. Empty string in production. Deduped per request.
	 */
	string function viteClient(){
		return variables.service.viteClient( moduleName = variables.moduleName );
	}

	/**
	 * True when the bound module's driver is in dev/hot mode.
	 */
	boolean function isHot(){
		return variables.service.isHot( moduleName = variables.moduleName );
	}

	/**
	 * Return the normalized bundle struct ({ js, css[], preload[] }) for an
	 * entry through the bound module's driver.
	 *
	 * @entry   Logical entry path.
	 * @options Optional struct: { renderModulePreload, includeImportedCss }.
	 */
	struct function bundle( required string entry, struct options = {} ){
		return variables.service.bundle(
			entry      = arguments.entry,
			moduleName = variables.moduleName,
			options    = arguments.options
		);
	}

	/**
	 * Drop all caches for the bound module. Useful in tests and dev workflows.
	 */
	function refresh(){
		variables.service.refresh( moduleName = variables.moduleName );
	}

}
