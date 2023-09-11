# Mixr

![Mixr Logo](https://github.com/homestar9/mixr/blob/master/mixr.svg?raw=true)

Mixr is a simple, yet flexible static asset helper for Coldbox applications.  Mixr can be configured to use a variety of conventions including Coldbox Elixir, Laravel Mix, or even custom asset bundlers.

Use Mixr in your app to automatically generate correct distribition asset paths in your Coldbox views and layouts.  Mixr automatically parses and maps asset manifests files to return the real path.

Mixr registers itself as a Coldbox helper method so you can call it in your handlers, layouts, and views by simply calling `mixr()`.

## Installation

Install Mixr using CommandBox:

```bash
box install mixr
```

## Configuration

Configure Mixr in your Coldbox `config/Coldbox.cfc` file:

```js
moduleSettings = {
    // default configuration designed to emulate Coldbox Elixir
    mixr: {
        "manifestPath" = "/includes/rev-manifest.json",
        "prependModuleRoot" = true,
        "prependPath" = "",
        "modules": {}
    }
};
```

## Settings

| Setting | Description | Default |
| --- | --- | --- |
| `manifestPath` | (string) The path from the root where your manifest file resides | /includes/rev-manifest.json |
| `prependModuleRoot` | (boolean) Whether or not to prepend the module root to the path | true |
| `prependPath` | (string) A path to prepend to the asset path | "" |
| `modules` | (struct) A struct of module names so you can pass along custom configs to submodules | {} |

## Submodule Settings

Sometimes a tracked or untracked submodule needs to use its own asset manifest file conventions. For example, if you use Laravel Mix in your main app, but you use Coldbox Elixir in a submodule, you can configure Mixr to use different settings for each submodule.  

### Method 1: Configure Via ModuleConfig.cfc *(recommended)*

Within the module's `ModuleConfig.cfc` file, add a `mixr` struct to the `configure()` method:

```js
function configure(){
    
    // module settings - we are overriding mixr conventions in this module
    variables.settings = {
        mixr: {
            "manifestPath": "/includes/mix-manifest.json",
            "prependModuleRoot": true,
            "prependPath": "/includes" 
        }
    };

}
```

### Method 2: Configure Via Coldbox.cfc

You can also configure Mixr in your main `config/Coldbox.cfc` file.  Add your module name to the `mixr.modules`  in `moduleSettings` like this:

```js
moduleSettings = {
    // default configuration designed to emulate Coldbox Elixir
    mixr: {
        "manifestPath" = "/includes/rev-manifest.json",
        "prependModuleRoot" = true,
        "prependPath" = "",
        "modules": {
            // custom configuration for a submodule
            "fooModule": {
                "manifestPath": "/includes/mix-manifest.json",
                "prependModuleRoot": true,
                "prependPath": "/includes"  
            }
        }
    }
};
```


## Usage

To return an asset path, simply call `mixr()` in your views, layouts, or handlers like this:
```html
// load javascript asset
<script src="#mixr( '/js/app.js' )#"></script>
// load css assset
<script src="#mixr( '/css/app.css' )#"></script>
```

#### Method Arguments

`mixr()` accepts the following arguments:

| Agument | Description | Default |  
| --- | --- | --- |
| `asset`* | (string) The path to the asset as it exists in the manifest file | "" |
| `moduleName` | (string) module name where the manifest file is located | [currentModuleName] |
| `manifestPath` | (string) The path from the root of the module where the manifest file resides | [config.manifestPath] |
| `prependModuleRoot` | (boolean) Whether or not to prepend the module root to the path | [config.prependModuleRoot] |
| `prependPath` | (string) A path to prepend to the asset path | [config.prependPath] |

Mixr automatically attempts to figure out which module the request is coming from and will prepend the module root to the path if `prependModuleRoot` is set to `true`.

### Examples

#### Coldbox Elixir

No need to change any defaults. It should work out of the box.

```js
// config/Coldbox.cfc
```

#### Laravel Mix

```js
// configure mixr to use laravel mix conventions
mixr = {
    "manifestPath": "/includes/mix-manifest.json",
    "prependModuleRoot": true,
    "prependPath": "includes",
    "modules": {}
}
```

#### Custom Asset Bundler

```js
// custom maifest file located in /dist/custom-manifest.json
{
    "js/app.js": "js/app.12345678.js",
    "css/app.css": "css/app.87654321.css"
}
```

```js
mixr = {
    "manifestPath": "/dist/custom-manifest.json",
    "prependModuleRoot": true,
    "prependPath": "dist", // prepend the 'dist' folder to the path
    "modules": {}
}
```

## Why Mixr?

Why would this module be useful if Coldbox Elixir already exists?  

 - Coldbox Elixir is a great asset helper, but it is not flexible enough to work with other asset bundlers like Laravel Mix.  Mixr is designed to work with any asset bundler that generates a manifest file. 
 - Mixr registers itself as a Coldbox helper method, so it can automatically detect which module you are in any time you call `mixr()`
 - Calling `mixr()` is quick and easy, and will keep your source code nice and clean.
 - You can configure different settings for each submodule giving you maximum control over your assets and manifest files.


 ## Roadmap:

 - Integration tests: I currently have unit tests in place, but would like to set up some better real-world testing for this module.

## About the Author:

This module was passionately developed by [Angry Sam Productions](https://www.angrysam.com), a web development company based in California. We believe creating and contributing open source software strenghens the development community and makes the world a better place.  If you would like to learn more about our company or hire us for your next project, please [contact us](https://www.angrysam.com/).
