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
    // default configuration designed to emulate Laravel Mix 6
    mixr: {
        "manifestPath" = "/includes/mix-manifest.json",
        "prependModuleRoot" = true,
        "prependPath" = "/includes",
        "modules": {}
    }
};
```

The above configuration will work in a ColdBox app that uses Laravel 6 to generate asset manifests.  If you are using Coldbox Elixir, you will need to change the configuration to match the conventions of your asset bundler.  See the [Upgrade Guide](#upgrade-guide) for more information.

For reference, a Laravel 6 Manifest file might look like this:

```js
{
    "/css/app.css": "/css/app.css?id=123",
    "/js/app.js": "/js/app.js?id=123"
}
```

The same manifest file might look like this when using Coldbox Elixir. You will need to update the default configuration if you are using Coldbox Elixir starting with Mixr version 2.0:

```js
{
    "includes/js/app.js": "includes/js/app.123.js",
    "includes/css/app.css": "includes/css/app.123.css"
}
``` 

## Upgrade Guide

### Upgrading from 1.x to 2.x

Version 2.0 introduces a **breaking change** where the configuration defaults have been changed to emulate Laravel Mix 6.  If you are upgrading from 1.x to 2.x, and you use Coldbox Elixir, you will need to update your configuration (see examples for details)

## Settings

| Setting | Description | Default |
| --- | --- | --- |
| `manifestPath` | (string) The path from the root where your manifest file resides | /includes/mix-manifest.json |
| `prependModuleRoot` | (boolean) Whether or not to prepend the module root to the path | true |
| `prependPath` | (string) A path to prepend to the asset path | /includes |
| `modules` | (struct) A struct of module names so you can pass along custom configs to submodules | {} |

## Submodule Settings

Sometimes a tracked or untracked submodule needs to use its own asset manifest file conventions. For example, if you use Laravel Mix in your main app, but you use Coldbox Elixir in a submodule, you can configure Mixr to use different settings for each submodule.  

### Configure Via Submodule's ModuleConfig.cfc

You can provide module-specific settings to Mixr, just in case some submodules use different conventions.  To do this within a module's `ModuleConfig.cfc` file, add a `mixr` struct to the `configure()` method:

```js
function configure(){
    
    // module settings - we are overriding mixr conventions in this module to emulate Coldbox Elixir
    variables.settings = {
        mixr: {
            "manifestPath": "/includes/rev-manifest.json",
            "prependModuleRoot": true,
            "prependPath": "" 
        }
    };

}
```

### Configure Via Coldbox.cfc

Alternatively, you can also configure Mixr in your main `config/Coldbox.cfc` file.  Add any submodule to the `mixr.modules`  in `moduleSettings` like this to override settings:

```js
moduleSettings = {
    // default configuration designed to emulate Coldbox Elixir
    mixr: {
        "manifestPath" = "/includes/rev-manifest.json",
        "prependModuleRoot" = true,
        "prependPath" = "",
        "modules": {
            // custom configuration for a submodule to emaulate Laravel Mix V6
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

```js
// config/Coldbox.cfc
mixr = {
    "manifestPath": "/includes/rev-manifest.json",
    "prependModuleRoot": true,
    "prependPath": "",
    "modules": {}
}
```

#### Laravel Mix

No need to change any defaults. It should work out of the box. Here is the configuration, just in case you need to change it:

```js
// configure mixr to use laravel mix conventions
mixr = {
    "manifestPath": "/includes/mix-manifest.json",
    "prependModuleRoot": true,
    "prependPath": "/includes",
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

Why Does Coldbox need another asset helper?  Here are a few reasons why Mixr is a great choice for your Coldbox app: 

 - Coldbox Elixir is a great asset helper, but it is not flexible enough to work with other asset bundlers like Laravel Mix.  Mixr is designed to work with any asset bundler that generates a manifest file. 
 - Mixr registers itself as a Coldbox helper method, so it can automatically detect which module you are in any time you call `mixr()`
 - Calling `mixr()` is quick and easy, and will keep your source code nice and clean.
 - You can configure different settings for each submodule giving you maximum control over your assets and manifest files.


 ## Roadmap:

 - Integration tests: I currently have unit tests in place, but would like to set up some better real-world testing for this module.

## About the Author:

This module was passionately developed by [Angry Sam Productions](https://www.angrysam.com), a web development company based in California. We believe creating and contributing open source software strenghens the development community and makes the world a better place.  If you would like to learn more about our company or hire us for your next project, please [contact us](https://www.angrysam.com/).

## Running Tests

To run the tests, simply run the following command from the root of the project in Commandbox:
`start server-lucee@5.json` (or whichever server JSON you want to use)
`server open` (to open the server in your browser)
navigate to `/tests/runner.cfm` in your browser

```bash
