component 
    hint="I am the mixr service."
    singleton
{

    property name="settings" inject="coldbox:moduleSettings:mixr";


    // this will hold a reference to all manifest maps
    variables._manifests = {}; 
    variables._rootSettings = {};


    /**
     *  Constructor
     */ 
    Mixr function init() {
        return this;
    }


    /**
     * Get
     * Returns the mapped path of the asset based on a manifest file
     * 
     * @path the key to look for in the manifest file
     * @moduleName the name of the module containing the asset (used when getting custom settings)
     * @manifestPath the path inside the module where the manfest file is including filename
     * @moduleRoot the path to the root of the module
     * @prependModuleRoot whether the module root path should be prepended to the final output
     * @prependPath anything you want prepeneded to the asset path just after the module root
     */
    string function get( 
        required string path, 
        required string moduleName,
        string manifestPath,
        string moduleRoot = "",
        boolean prependModuleRoot,
        string prependPath
    ) {

        applyDefaults( arguments );
        var manifest = getManifest( arguments.moduleRoot & "/" & arguments.manifestPath );

        if ( !manifest.keyExists( path ) ) {
            throw( 
                message = "asset file not found in manifest", 
                type = "ManifestAssetNotFound", 
                detail = "Looked for #path# in manifest file #manifestPath#" 
            );
        }

        return buildPath(
            path = manifest[ path ],
            moduleRoot = arguments.moduleRoot,
            prependModuleRoot = arguments.prependModuleRoot,
            prependPath = arguments.prependPath
        );

    }

    /**
     * buildPath
     * Assembles the final output path based on passed preferences/arguments
     *
     * @path the path of the asset from the manifest file
     * @moduleRoot the module rooth path
     * @prependModuleRoot whether we should prepend the module root
     * @prependPath anything else we want added just before the asset path and after the module root
     */
    private function buildPath(
        required string path,
        required string moduleRoot,
        required boolean prependModuleRoot,
        required string prependPath
    ) {
        return ( prependModuleRoot ? moduleRoot : '' ) & prependPath & path;
    }

    /**
     * Applies any defaults to the settings
     *
     * @args the arguments to check and apply module defaults to
     */
    private function applyDefaults( required struct args ) {

        settings.each( function( key, value ) {
            
            // if this is the modules setting, or if the setting already exists in the args, skip it.
            if ( key == "modules" || args.keyExists( key ) ) {
                return;
            }

            // assert: argument is missing, look for a module setting
            if ( 
                len( args.moduleName ) && 
                settings.modules.keyExists( args.moduleName ) && 
                settings.modules[ args.moduleName ].keyExists( key )
            ) {
                args[ key ] = settings.modules[ args.modulename ][ key ];
                return;
            }

            // inherit setting from the root
            args[ key ] = value;

        } );

    }   

    /**
     * getManifest
     * Returns the manifest struct
     *
     * @manifestPath the path to the manifest file
     */
    private struct function getManifest( required string manifestPath ) {

        // remove duplicate slashes
        arguments.manifestPath = reReplace( manifestPath, "^//?", "" ); 

        // if the file isn't cached
        if ( !variables._manifests.keyExists( arguments.manifestPath ) ) {

            // race condition double lock-check technique
            lock
                name="mixr"
                type="exclusive"
                timeout=30
            {
                if ( !variables._manifests.keyExists( arguments.manifestPath ) ) {
                    variables._manifests[  arguments.manifestPath ] = importManifestFile( arguments.manifestPath );
                }
            }

        }
        
        return variables._manifests[ manifestPath ];

    }

    private struct function importManifestFile( manifestPath ) {
        if ( !fileExists( arguments.manifestPath ) ) {
            throw( 
                message = "manifest file not found", 
                type = "ManifestNotFound", 
                detail = "Checked #arguments.manifestPath#" 
            );
        }

        return deserializeJson( fileRead( manifestPath ) );
    }

}