# Mixr

![Mixr Logo](https://github.com/homestar9/mixr/blob/master/mixr-logo.webp?raw=true)

**Mixr** is a static-asset helper for ColdBox applications.

Instead of hard-coding the hashed CSS and JavaScript filenames created by your build process, reference the original asset entry:

```cfml
#mixr().tags( "resources/js/app.js" )#
```

Mixr looks up that entry in your bundler's manifest and renders the correct HTML for the current environment.

In production, that may include a stylesheet, module-preload hints, and a hashed JavaScript bundle:

```html
<link rel="stylesheet" href="/includes/build/assets/app-a1b2c3d4.css" />
<link rel="modulepreload" href="/includes/build/assets/vendor-e5f6g7h8.js" />
<script type="module" src="/includes/build/assets/app-a1b2c3d4.js"></script>
```

In development, Mixr can detect Vite's hot file and render the Vite development-server URLs instead.

Mixr supports:

- Vite
- Webpack
- Laravel Mix
- ColdBox Elixir
- Custom flat manifests
- Traditional ColdBox multi-page applications
- Single-page applications
- Module-specific assets

The `mixr()` helper is available in handlers, layouts, views, and interceptors.

## Engine support

- Lucee 5 and 6+
- Adobe ColdFusion 2023, 2025+
- BoxLang 1+

## Table of contents

- [Install via CommandBox](#install-via-commandbox)
- [Choose your setup](#choose-your-setup)
- [Vite Driver](#vite-driver-instructions)
- [Manifest Driver](#manifest-driver-instructions-webpack-laravel-mix-elixir)
- [Everyday usage](#everyday-usage)
- [HTML attributes](#html-attributes)
- [Configuration reference](#configuration-reference)
- [Module-aware configuration](#module-aware-configuration)
- [Critical CSS](#critical-css)
- [Splitting CSS and JavaScript rendering](#splitting-css-and-javascript-rendering)
- [Manual rendering with bundle()](#manual-rendering-with-bundle)
- [Upgrade guide: 2.x to 3.0](#upgrade-guide-2x-to-30)
- [Troubleshooting](#troubleshooting)

---

## Install via CommandBox

```bash
box install mixr
```

## Choose your setup

Mixr ships with a few drivers for different bundling strategies. Use this table to pick the right one.

| Your project uses... | Driver | Start here |
| --- | --- | --- |
| Vite, a `.vite/manifest.json`, or a Vite dev server | `"vite"` | [Vite Driver](#vite-driver-instructions) |
| Webpack, Laravel Mix, Elixir, `mix-manifest.json`, `rev-manifest.json`, or a flat asset map | `"manifest"` | [Manifest Driver](#manifest-driver-instructions-webpack-laravel-mix-elixir) |
| A build system you are unsure about | `"auto"` | [Driver selection](#driver-selection) |
| An existing Mixr 2.x application | `"manifest"` or `"auto"` | [Upgrade guide](#upgrade-guide-2x-to-30) |

### What is a manifest?

> A manifest is a JSON file your build process creates. It maps an original source file like `resources/js/app.js` to the fingerprinted production file your bundler generated, like `assets/app-a1b2c3d4.js`. Mixr reads that file so your ColdBox code can keep using stable, human-readable asset names.

---

## Vite Driver Instructions

**Vite is the recommended choice for new projects.** It supports fast development builds, hot-module replacement, modern JavaScript modules, content-hashed production assets, imported CSS, and shared chunk preloading.

### 1. Configure Mixr

Add a basic Vite configuration to `config/Coldbox.cfc`:

```cfml
moduleSettings = {
    mixr : {
        driver  : "vite",
        devMode : getSystemSetting( "ENVIRONMENT", "production" ) eq "development"
    }
};
```

By default, Mixr expects Vite to use these locations. Only set custom paths when your Vite setup writes files somewhere different.

| Purpose | Default |
| --- | --- |
| Production manifest | `/includes/build/.vite/manifest.json` |
| Vite hot file | `/includes/hot` |
| Public build URL | `/includes/build` |

```cfml
moduleSettings = {
    mixr : {
        driver       : "vite",
        manifestPath : "/includes/build/.vite/manifest.json",
        buildPath    : "/includes/build",
        hotFilePath  : "/includes/hot",
        devMode      : getSystemSetting( "ENVIRONMENT", "production" ) eq "development"
    }
};
```

### 2. Add Mixr to your layout

Place `viteClient()` and `tags()` inside `<head>`:

```cfml
<!doctype html>
<html lang="en">
<head>
    #mixr().viteClient()#
    #mixr().tags( "resources/js/app.js" )#
</head>
<body>

    #renderView()#

</body>
</html>
```

The entry passed to `tags()` must match a key in Vite's manifest, which is normally the original source entry (`resources/js/app.js`), not the compiled filename (`assets/app-a1b2c3d4.js`).

Your global entry might import shared CSS and JavaScript:

```js
import "../scss/app.scss";
import "./bootstrap";
import "./navigation";
```

Every page rendered through that layout receives the same base assets.

> Mixr does not require your application to be a single page app. It resolves and renders whichever entries you ask for, which suits traditional multi-page apps too.

If you bundle JS and CSS separately, load both entries:

```cfml
<head>
    #mixr().viteClient()#
    #mixr().tags( "resources/js/app.js" )#     <!-- JavaScript -->
    #mixr().tags( "resources/scss/app.scss" )# <!-- CSS -->
</head>
```

### What happens in development?

When `devMode` is enabled and Vite's hot file is active, Mixr renders Vite development-server URLs:

```html
<script type="module" src="http://localhost:5173/@vite/client"></script>
<script type="module" src="http://localhost:5173/resources/js/app.js"></script>
```

Vite then handles hot-module replacement, JavaScript updates, CSS injection, and fast local rebuilds.

### What happens in production?

When Vite hot mode is not active, Mixr reads Vite's production manifest. For a JavaScript entry it can render imported stylesheet links, module-preload links for shared chunks, and the entry `<script type="module">`. For that reason, `tags()` is the recommended helper for Vite JavaScript entries.

> **Important for Vite users:** `path()` returns only the compiled entry URL. It does not include imported CSS, shared chunks, module-preload hints, or critical CSS. Use `tags()` for most Vite entries.

### Adding page-specific entries

You do not need a separate entry per ColdBox event. Start with one global entry, then add page-specific entries only when a route has substantial JavaScript or CSS that should not load everywhere.

```text
resources/
├── js/
│   ├── app.js
│   └── pages/
│       ├── dashboard.js
│       └── checkout.js
└── scss/
    └── app.scss
```

The main layout loads shared assets, and a dashboard layout or view loads an additional entry:

```cfml
#mixr().tags( "resources/js/pages/dashboard.js" )#
```

> Mixr does not register Vite inputs for you. Your Vite configuration must still define any files you want Vite to treat as build entries.

---

## Manifest Driver Instructions (Webpack, Laravel Mix, Elixir)

Use the manifest driver for build systems that create a simple source-to-output mapping, such as Webpack, Laravel Mix, ColdBox Elixir, or a custom `mix-manifest.json` / `rev-manifest.json`.

Unlike Vite manifests, a flat manifest typically maps one requested asset to one output URL:

```json
{
    "/css/app.css": "/css/app-123456.css",
    "/js/app.js": "/js/app-abcdef.js"
}
```

### 1. Configure Mixr for flat manifests

```cfml
moduleSettings = {
    mixr : {
        driver            : "manifest",
        manifestPath      : "/includes/mix-manifest.json",
        prependModuleRoot : true,
        prependPath       : "/includes"
    }
};
```

### 2. Render your asset URLs

The Mixr 2.x string form remains a clean choice for flat manifests:

```cfml
<link rel="stylesheet" href="#mixr( '/css/app.css' )#" />
<script src="#mixr( '/js/app.js' )#"></script>
```

The fluent API works too:

```cfml
<link rel="stylesheet" href="#mixr().path( '/css/app.css' )#" />
<script src="#mixr().path( '/js/app.js' )#"></script>
```

Both resolve the hashed asset URL while leaving the HTML markup under your control. A flat manifest usually does not describe imported CSS or shared-chunk relationships, so you normally load CSS and JavaScript entries explicitly, adding page-specific bundles only where needed.

---

## Everyday usage

Mixr supports a fluent API for modern usage and a legacy string form for 2.x compatibility.

### Recommended helper by situation

| Situation | Recommended helper |
| --- | --- |
| Vite JavaScript entry | `mixr().tags( "resources/js/app.js" )` |
| Vite CSS-only entry | `mixr().tags( "resources/scss/app.scss" )` |
| Flat manifest application | `mixr( "/js/app.js" )` or `mixr().path( "/js/app.js" )` |
| CSS and JavaScript need different placement | `cssTags()` and `jsTags()` |
| Complete control over markup | `bundle()` and `criticalCss()` |
| Upgrading a 2.x app | Keep the string form until you need Vite-specific behavior |

### The `mixr()` helper

```cfml
<!--- Fluent API, current module auto-detected. --->
#mixr().tags( "resources/js/app.js" )#
#mixr().path( "resources/js/app.js" )#
#mixr().viteClient()#

<!--- Fluent API, explicit module. --->
#mixr( moduleName = "admin" ).tags( "resources/js/admin.js" )#

<!--- Legacy 2.x string form. Returns a URL. --->
#mixr( "/js/app.js" )#
#mixr( "/js/admin.js", "admin" )#
```

When you omit `moduleName`, Mixr determines the current module automatically, so layouts, handlers, views, and interceptors inside a module use the correct configuration without naming the module each time.

### Fluent methods

| Method | Returns | Description |
| --- | --- | --- |
| `path( entry )` | `string` | Resolved URL for one entry. Best for flat manifests or fully manual markup. |
| `tags( entry )` | `string` | Complete asset markup. With Vite, can include CSS links, module-preload links, and a module script. |
| `cssTags( entry )` | `string` | The CSS portion of `tags()`. Useful when CSS must appear in `<head>`. |
| `jsTags( entry )` | `string` | The JavaScript portion of `tags()`. Useful when JS must render elsewhere. |
| `bundle( entry )` | `struct` | Resolved assets so you can render HTML yourself. |
| `criticalCss( eventName )` | `string` | Inline critical CSS for an event when enabled and available. |
| `viteClient()` | `string` | Vite's `@vite/client` script in development. Empty in production. Deduped per request. |
| `isHot()` | `boolean` | `true` when Vite hot mode is active for the current configuration. |
| `refresh()` | `void` | Clears Mixr's cached data for the current module. Useful in tests. |

---

## HTML attributes

`tags()`, `cssTags()`, and `jsTags()` accept an options struct. Use the `attributes` key to add HTML attributes to the tag Mixr renders.

```cfml
#mixr().tags(
    "resources/js/app.js",
    { attributes : { nonce : request.cspNonce, "data-app" : "public" } }
)#
```

```html
<script type="module" src="..." nonce="..." data-app="public"></script>
```

### The general rule

**Attributes decorate the tag the entry actually renders.**

- **Flat manifests** (Laravel Mix, Elixir, Webpack, custom): a CSS entry renders one `<link>`, a JavaScript entry renders one `<script>`, and the attributes apply to that one tag.
- **Vite JavaScript entries**: attributes apply to the entry `<script type="module">`. Imported stylesheet links and module-preload links do not receive them automatically.
- **Vite CSS-only entries**: production renders a stylesheet `<link>`; development renders a Vite module script. `tags()` handles both modes, so prefer it for CSS-only entries unless you specifically need to split rendering.

For example, a stylesheet entry with attributes:

```cfml
#mixr().tags( "resources/scss/app.scss", { attributes : { media : "screen", "data-theme" : "dark" } } )#
```

```html
<!-- production --> <link rel="stylesheet" href="..." media="screen" data-theme="dark" />
<!-- development --> <script type="module" src=".../app.scss" media="screen" data-theme="dark"></script>
```

### Different attributes for CSS and JavaScript

Use `cssTags()` and `jsTags()` when CSS and JavaScript need different attributes or placement. For a Vite JavaScript entry, `cssTags()` applies its attributes to every stylesheet link it emits, while `jsTags()` applies its attributes to the entry module script and renders module-preload links when enabled.

```cfml
#mixr().cssTags( "resources/js/app.js", { attributes : { media : "screen" } } )#
#mixr().jsTags(  "resources/js/app.js", { attributes : { nonce : request.cspNonce } } )#
```

> **CSS-only entry note:** In Vite development mode `cssTags()` returns an empty string because Vite injects those styles through JavaScript. When splitting a CSS-only entry, include both `cssTags()` and `jsTags()`.

### Attribute behavior

The `attributes` struct is open-ended. Mixr renders any valid attribute key you provide, so new HTML attributes work without a Mixr update.

- **Boolean attributes:** pass an actual boolean. `{ async : true }` renders a bare `async`; `false` (or omitting the key) renders nothing. Note `{ defer : 1 }` renders `defer="1"` because `1` is a number, not a boolean.
- **Escaping:** attribute values are HTML-escaped; keys are lowercased and emitted as provided. Build attribute keys from trusted application code, not end-user input.
- **Integrity / SRI:** Mixr renders an `integrity` value if you pass one, but it does not compute the hash. Your build pipeline must generate it, which matters with Vite because content-hashed filenames change each build.

> **Vite note:** Module scripts are deferred by default, so adding `defer` to a Vite module script is usually unnecessary.

Common attributes you might pass: `nonce`, `async`, `defer`, `crossorigin`, `integrity`, `fetchpriority`, `referrerpolicy`, `media`, and any `data-*` or `aria-*` attribute.

---

## Configuration reference

You only need to configure settings you are changing. The quick-start examples cover the most common setups; this section is a reference for custom build locations, multiple modules, special cache behavior, or critical CSS.

### Path conventions

Some settings identify files Mixr reads. Others become public URLs that browsers request.

| Setting type | Examples | Purpose |
| --- | --- | --- |
| File-oriented paths | `manifestPath`, `hotFilePath`, `criticalCss.path` | Where Mixr finds files or directories it reads. |
| Browser-facing URL prefixes | `buildPath`, `prependPath` | Become part of the URL rendered in `<link>` and `<script>` tags. |

### Driver selection

| Driver | Use it when... |
| --- | --- |
| `"vite"` | Your project uses Vite, Vite's hot file, or a Vite manifest. |
| `"manifest"` | Your project uses a simple source-to-output manifest (Laravel Mix, Elixir, Webpack, or a custom map). |
| `"auto"` | You want Mixr to detect the right driver. |

In `"auto"` mode, Mixr selects Vite when it finds an active Vite hot file, or a Vite-shaped manifest (its first entry is a struct with a `file` key). Otherwise it falls back to the flat-manifest driver.

### Configuration table

| Setting | Default | Description |
| --- | --- | --- |
| `driver` | `"auto"` | `"vite"`, `"manifest"`, or `"auto"`. |
| `manifestPath` | `"/includes/build/.vite/manifest.json"` | Location of the bundler's manifest JSON file. |
| `buildPath` | `"/includes/build"` | Public URL prefix for Vite-built assets. |
| `hotFilePath` | `"/includes/hot"` | Location of Vite's hot file. Its presence enables dev-server rendering when `devMode` is on. |
| `devServerUrl` | `""` | Fallback dev-server URL when the hot file is empty. |
| `devMode` | `false` | Enables Vite hot-file checking. Set `true` in development. |
| `renderModulePreload` | `true` | Renders `<link rel="modulepreload">` for imported JavaScript chunks. |
| `includeImportedCss` | `true` | Walks imported Vite chunks and includes their CSS files. |
| `prependModuleRoot` | `true` | Prefixes generated URLs with the current module's mount path. Applies to both drivers. |
| `prependPath` | `"/includes"` | Flat-manifest-only public URL prefix prepended to resolved paths. |
| `cache.enabled` | `true` | Caches parsed manifests in memory. |
| `cache.devCheckInterval` | `2000` | How often Mixr rechecks Vite's hot file in dev, in milliseconds. |
| `criticalCss.enabled` | `false` | Enables critical CSS rendering. |
| `criticalCss.path` | `"/includes/critical"` | Directory containing per-route critical CSS files. |
| `criticalCss.suffix` | `".critical.css"` | Suffix appended to the event name when locating a critical CSS file. |
| `modules` | `{}` | Per-module overrides keyed by module name. |

### Cache behavior

The `cache` and `criticalCss` structs merge key-by-key. Overriding just `cache: { devCheckInterval: 5000 }` does not disable caching; the default `cache.enabled = true` still applies.

`cache.devCheckInterval` controls how Mixr rechecks Vite's hot file in development:

| Value | Behavior |
| --- | --- |
| Positive number | Rechecks at that interval, in milliseconds. |
| `0` | Rechecks on every request. |
| `-1` | Never rechecks after initial resolution. Treats dev behavior like production. |

---

> **The sections below are advanced and optional.** Most applications are fully set up after the Configuration reference. Read on only when you need multi-module asset pipelines, critical CSS, split CSS/JS placement, or hand-rolled markup.

## Module-aware configuration

Mixr can use different asset settings for different ColdBox modules, which is valuable for reusable or distributed modules that ship with their own JavaScript and CSS. A module can own its frontend assets without the host application merging manifests, duplicating build configuration, or managing module-specific URLs.

### Normal module usage

In most cases, call Mixr normally from within the module:

```cfml
#mixr().tags( "resources/js/app.js" )#
```

Mixr detects the current module and uses that module's configuration when one exists. You do not usually need to pass the module name from a module's own layouts, handlers, views, or interceptors.

### Configure module overrides from the host

A host (root) application can provide module-specific overrides through `moduleSettings.mixr.modules`:

```cfml
moduleSettings = {
    mixr : {
        driver       : "vite",
        manifestPath : "/includes/build/.vite/manifest.json",
        buildPath    : "/includes/build",
        devMode      : getSystemSetting( "ENVIRONMENT", "production" ) eq "development",

        modules : {
            admin : {
                driver       : "vite",
                manifestPath : "/admin/includes/build/.vite/manifest.json",
                buildPath    : "/admin/includes/build",
                hotFilePath  : "/admin/includes/hot"
            },
            reports : {
                driver       : "manifest",
                manifestPath : "/reports/includes/mix-manifest.json",
                prependPath  : "/reports/includes"
            }
        }
    }
};
```

With that configuration, the same `#mixr().tags( "resources/js/app.js" )#` call resolves differently depending on whether the request belongs to the host, the `admin` module, or the `reports` module.

### Let a module define its own settings

A module can also provide its own Mixr configuration in `ModuleConfig.cfc`:

```cfml
component {
    function configure() {
        variables.settings.mixr = {
            driver       : "vite",
            manifestPath : "/includes/build/.vite/manifest.json",
            buildPath    : "/includes/build",
            devMode      : getSystemSetting( "ENVIRONMENT", "production" ) eq "development"
        };
    }
}
```

This lets a reusable module describe its own build process without the host knowing every internal asset detail.

### Module settings are independent

Root application settings do **not** automatically cascade into every module. This host configuration:

```cfml
moduleSettings = { mixr : { driver : "vite", devMode : true } };
```

does not force every module to inherit `driver: "vite"` and `devMode: true`. A module should either define its own `variables.settings.mixr`, or receive an explicit override through `moduleSettings.mixr.modules.<moduleName>`. This avoids surprises when modules use different manifests, build paths, dev servers, or bundlers. For most apps: keep host settings focused on host assets, let reusable modules define their own settings, and use `mixr.modules.<name>` only when the host needs to adapt a module's paths.

### Explicitly target a module

When you intentionally need an asset from another module (for example, a host layout including admin assets), pass `moduleName`:

```cfml
<head>
    #mixr().tags( "resources/js/app.js" )#
    #mixr( moduleName = "admin" ).tags( "resources/js/admin.js" )#
</head>
```

### Module mount paths and generated URLs

By default, Mixr makes generated asset URLs aware of the module's mount path. A module mounted at `/admin` with `buildPath : "/includes/build"` generates a URL like:

```text
/admin/includes/build/assets/app-a1b2c3d4.js
```

This lets a module work even when the host mounts it at a different path than expected. Set `prependModuleRoot : false` when a module's assets should always resolve from a shared, application-level location. Vite development-server URLs are absolute, so they are never prefixed with a mount path.

---

## Critical CSS

Critical CSS is an optional performance optimization: inline the CSS needed for the above-the-fold part of the page, load the rest of the stylesheet asynchronously, and keep a standard stylesheet fallback for users with JavaScript disabled.

It can improve first-render performance on CSS-heavy pages, but adds build, maintenance, and Content Security Policy considerations. Enable it after measuring a real need. Mixr handles the rendering side; your build process generates the per-route files, with tools like [`rollup-plugin-critical`](https://github.com/nystudio107/rollup-plugin-critical), [`laravel-mix-critical`](https://github.com/michtio/laravel-mix-criticalcss), or a custom process.

### Enable it

1. Place per-route critical CSS files in your configured directory (default `/includes/critical`), named after the current event: `main.index.critical.css`, `blog.show.critical.css`.
2. Enable the feature, optionally setting `path` and `suffix`:

```cfml
moduleSettings = {
    mixr : {
        criticalCss : {
            enabled : true,
            path    : "/includes/critical",
            suffix  : ".critical.css"
        }
    }
};
```

A `suffix` of `"_critical.min.css"` would look for `main.index_critical.min.css` instead. Keep calling `tags()` normally; Mixr checks for a critical file matching the current event.

### What `tags()` emits

Without critical CSS (default):

```html
<link rel="stylesheet" href="/includes/build/assets/app-a1b2c3d4.css" />
<link rel="modulepreload" href="/includes/build/assets/vendor-e5f6g7h8.js" />
<script type="module" src="/includes/build/assets/app-a1b2c3d4.js"></script>
```

With critical CSS enabled and a matching file for the current event:

```html
<style>/* Inlined critical CSS */</style>
<link rel="preload" as="style" href="/includes/build/assets/app-a1b2c3d4.css"
      onload="this.onload=null;this.rel='stylesheet'" fetchpriority="high" />
<noscript><link rel="stylesheet" href="/includes/build/assets/app-a1b2c3d4.css" /></noscript>
<link rel="modulepreload" href="/includes/build/assets/vendor-e5f6g7h8.js" />
<script type="module" src="/includes/build/assets/app-a1b2c3d4.js"></script>
```

If no matching file exists, Mixr silently falls back to normal stylesheet output. No conditional code is needed in your views.

### Per-call options

Pass critical CSS options through `tags()`:

```cfml
#mixr().tags( "resources/js/app.js", { criticalEvent : "blog.show", nonce : request.cspNonce } )#
```

| Option | Default | Description |
| --- | --- | --- |
| `criticalEvent` | Current event | Overrides the event name used to locate a critical CSS file. |
| `skipCritical` | `false` | Forces standard stylesheet output for this call. |
| `nonce` | `""` | Adds a CSP nonce to the inline `<style>` and preload `<link>`. |

### Development behavior

Mixr skips critical CSS whenever Vite hot mode is active, because Vite injects CSS through JavaScript and inlining a stale production file would fight it. To preview critical CSS locally, run a production build and load the app without Vite's hot file active.

### Content Security Policy note

The preload-swap pattern uses an inline `onload` handler:

```html
onload="this.onload=null;this.rel='stylesheet'"
```

A strict CSP may block inline event handlers. Adding a nonce to the inline `<style>` does not authorize the `onload` handler. Applications with strict CSP may need a different stylesheet-loading strategy, a CSP exception that permits the handler, or custom rendering with `bundle()`. Review your CSP before enabling critical CSS in production.

---

## Splitting CSS and JavaScript rendering

For Vite, the default recommendation is to keep the complete output in `<head>`. Vite module scripts are deferred by default, so this lets the browser discover stylesheets and module-preload hints early. Use split rendering only when your layout requires it, for example when CSS must render in `<head>` while JavaScript renders elsewhere, when CSS and JS need different attributes, or when you need direct control over markup.

### The easy split: `cssTags()` and `jsTags()`

```cfml
<!doctype html>
<html lang="en">
<head>
    #mixr().viteClient()#
    #mixr().cssTags( "resources/js/app.js" )#
</head>
<body>

    #renderView()#

    #mixr().jsTags( "resources/js/app.js" )#
</body>
</html>
```

For the same entry, `cssTags()` and `jsTags()` together render the same asset set as `tags()`.

- `cssTags()` renders stylesheet `<link>` tags, or inline critical CSS plus preload-swap markup and a `<noscript>` fallback when critical CSS is enabled.
- `jsTags()` renders module-preload links plus the entry module script (or the dev-server script in development).

Use either `tags()` or `cssTags()` plus `jsTags()` for the same entry in a request, not both. Critical-CSS dedupe is handled for you: the first `cssTags()` (or `tags()`) call per request emits the inline `<style>`, and later calls suppress it while still preload-swapping the CSS link.

### Development behavior

When Vite hot mode is active, `cssTags()` returns an empty string and `jsTags()` renders the dev-server script (Vite injects CSS through JavaScript). With `jsTags()` near the end of `<body>`, a brief flash of unstyled content may occur in development. That is usually acceptable locally, and is another reason `tags()` in `<head>` remains the preferred Vite pattern.

### Flat manifest applications

With a flat manifest, CSS and JavaScript are normally separate keys. Use the split with separate keys, or keep calling `tags()` twice:

```cfml
#mixr().cssTags( "/css/app.css" )#
#mixr().jsTags( "/js/app.js" )#
```

---

## Manual rendering with bundle()

Use `bundle()` when you need complete control over generated HTML, for example custom integrity attributes, specialized CSP markup, custom preload hints, or non-standard script placement.

```cfml
<cfset bundle   = mixr().bundle( "resources/js/app.js" )>
<cfset critical = mixr().criticalCss( options = { markRendered : true } )>

<!doctype html>
<html lang="en">
<head>

    <cfif len( critical )>
        <style>#critical#</style>
    </cfif>

    <cfloop array="#bundle.css#" item="href">
        <link rel="stylesheet" href="#href#" />
    </cfloop>

</head>
<body>

    #renderView()#

    <cfloop array="#bundle.preload#" item="href">
        <link rel="modulepreload" href="#href#" />
    </cfloop>

    <cfif len( bundle.js )>
        <script type="module" src="#bundle.js#"></script>
    </cfif>

</body>
</html>
```

### Return value

`bundle()` returns a struct:

| Key | Description |
| --- | --- |
| `js` | The resolved JavaScript entry URL (empty for CSS-only entries). |
| `css` | An array of stylesheet URLs. |
| `preload` | An array of imported JavaScript chunk URLs. |
| `criticalCss` | The resolved critical CSS body, when applicable. |

### Dedupe behavior

`bundle()` is a pure read. It does **not** mark inline critical CSS as rendered for the request, so combining a manual `bundle()` render with a later `tags()` call could produce duplicate inline critical CSS. When rendering critical CSS manually, mark it rendered so a later `tags()` call suppresses its own inline block:

```cfml
<cfset critical = mixr().criticalCss( options = { markRendered : true } )>
```

The first positional argument to `criticalCss()` is the event name, and options (including `markRendered`) are passed in the options struct. The flag is only set when the returned string is non-empty. To target a specific event: `mixr().criticalCss( "main.index", { markRendered : true } )`.

### Vite safety note

For Vite output, keep JavaScript as a module script (`<script type="module" src="#bundle.js#"></script>`). Vite output can contain ES module imports that require `type="module"`, so do not convert it to a classic script unless you know the generated file is not an ES module.

### Development behavior

When Vite hot mode is active, `bundle.css`, `bundle.preload`, and `bundle.criticalCss` are empty, and `bundle.js` holds the dev-server URL. Loops over the empty arrays safely do nothing. Branch on `mixr().isHot()` when you need substantially different development markup.

---

## Upgrade guide: 2.x to 3.0

Most existing Mixr 2.x templates keep working. The legacy string form is unchanged:

```cfml
#mixr( "/js/app.js" )#
```

The default driver is now `"auto"`, which still falls back to the flat-manifest driver when it does not find an active Vite configuration.

### The most important upgrade check

Mixr 3.0 changes the default manifest path:

| Version | Default `manifestPath` |
| --- | --- |
| 2.x | `/includes/mix-manifest.json` |
| 3.0 | `/includes/build/.vite/manifest.json` |

If your 2.x project relied on the old default and never set `manifestPath`, set it explicitly:

```cfml
mixr = {
    driver       : "manifest",   // or "auto"
    manifestPath : "/includes/mix-manifest.json"
};
```

If you miss this step, the `ManifestNotFound` error spells out the exact fix, so you can recover without this guide.

### New in 3.0

- **Drivers:** `driver = "vite" | "manifest" | "auto"` (default `"auto"`).
- **Vite settings:** `buildPath`, `hotFilePath`, `devServerUrl`, `devMode`, `renderModulePreload`, `includeImportedCss`, `cache.devCheckInterval`.
- **Fluent API:** `path()`, `tags()`, `cssTags()`, `jsTags()`, `bundle()`, `criticalCss()`, `viteClient()`, `isHot()`, `refresh()`.
- **Critical CSS** (opt-in): inline rendering with async stylesheet loading and a `<noscript>` fallback.
- **Module-aware configuration:** submodules use independent settings via their own `ModuleConfig.cfc` or `mixr.modules.<name>` from the host. Settings do not cascade.

### A note on `path()` with Vite

The legacy string form and `path()` stay clean and practical for flat manifests. For Vite, remember they return only the compiled entry file (see [What happens in production?](#what-happens-in-production)) and use `tags()` instead.

---

## Troubleshooting

### `ManifestNotFound`

Mixr cannot find the configured manifest file. Confirm your production build has run, that `manifestPath` points to the correct file, that the application can read it, and that your bundler outputs the manifest where Mixr expects it (Vite: `/includes/build/.vite/manifest.json`; Laravel Mix: `/includes/mix-manifest.json`).

### Mixr cannot find an entry

The asset path you passed does not match a manifest key. Open the manifest and copy the key exactly. If the manifest contains `"resources/js/app.js": { "file": "assets/app-a1b2c3d4.js" }`, call `mixr().tags( "resources/js/app.js" )`, not the compiled path.

### Production works, but Vite development mode does not

Mixr cannot find or use Vite's hot file. Confirm `devMode` is enabled, that `hotFilePath` matches the file Vite writes, that Vite is running, and that the hot file contains a reachable dev-server URL. Confirm Docker, WSL, VM, HTTPS, or reverse-proxy networking lets the browser reach that URL. Set `devServerUrl` when the hot file is empty or unsuitable for the environment.

### JavaScript loads, but imported Vite CSS is missing

You used `path()` and rendered only the JavaScript entry URL. Use `tags()`, or split with `cssTags()` and `jsTags()`.

### Generated module asset URLs return 404

The module mount path, `buildPath`, or module-root prefix behavior does not match your deployment. Confirm the module's mount path and that `buildPath` points to the correct public location. Review `prependModuleRoot`, and set it to `false` when assets should not inherit the module mount path.

### Critical CSS does not appear

Critical CSS is disabled, no matching file exists, or Vite hot mode is active. Confirm `criticalCss.enabled` is `true`, that `criticalCss.path` is correct, that the filename matches the current ColdBox event, that the suffix matches your build output, and that Vite's hot file is not active while testing production behavior.

### Critical CSS fails under a strict CSP

Your CSP blocks inline styles or inline event handlers. Confirm the nonce on your inline style is correct, check whether inline event handlers are blocked, and review the [Content Security Policy note](#content-security-policy-note). Consider `bundle()` when your CSP requires a different stylesheet-loading strategy.

---

## About the author

Mixr is developed by [Angry Sam Productions](https://www.angrysam.com). Issues, pull requests, bug reports, and ideas are welcome.