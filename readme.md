# Mixr

![Mixr Logo](https://github.com/homestar9/mixr/blob/master/mixr-logo.webp?raw=true)

**Mixr** resolves logical asset paths (`resources/js/app.js`) to the hashed
files your bundler emits and renders the `<script>` / `<link>` tags for you.

First-class support for **Vite** (production manifest + dev-server hot
reload), **Webpack**, **Laravel Mix**, **ColdBox Elixir**, and any custom flat-key
manifest. Registers a global `mixr()` helper available in every handler,
layout, view, and interceptor.

---

## Install via CommandBox

Installation is as simple as:

```bash
box install mixr
```

---

## Quick start (Vite)

Using Vite in your project? Add a `mixr` struct to your root app's

`config/Coldbox.cfc`:

```js
moduleSettings = {
    mixr: {
        driver       : "vite",
        manifestPath : "/includes/build/.vite/manifest.json",
        buildPath    : "/includes/build", 
        hotFilePath  : "/includes/hot",
        devMode      : getSystemSetting( "ENVIRONMENT", "production" ) eq "development"
    }
};
```

In your layout:

```html
<!DOCTYPE html>
<html>
<head>
    #mixr().viteClient()# <!-- ignored in when devMode is false -->
    #mixr().tags( "resources/js/app.js" )# <!-- css + preload + module script -->
</head>
<body>...</body>
</html>
```

That's it. In **dev** (when Vite has written its hot file), Mixr emits
dev-server URLs and `@vite/client`. In **prod**, it reads `manifest.json`
and emits hashed `<link rel="stylesheet">`, `<link rel="modulepreload">`,
and `<script type="module">` tags with CSS chunks and module preloads
collected automatically.

---

## The `mixr()` helper

There are three supported calling styles, all of which work with any driver:

```cfm
<!-- Fluent, current module (auto-detected) -->
#mixr().tags( "resources/js/app.js" )#
#mixr().path( "resources/js/app.js" )#
#mixr().viteClient()#

<!-- Fluent, explicit module -->
#mixr( moduleName = "admin" ).tags( "resources/js/admin.js" )#

<!-- Legacy 2.x string form (still supported, returns a URL) -->
#mixr( "/js/app.js" )#
#mixr( "/js/admin.js", "admin" )#
```

When `moduleName` is omitted, Mixr auto-detects the module handling the
current request, so submodule configs are picked up without extra wiring.

### Fluent methods

| Method | Returns | Notes |
| --- | --- | --- |
| `path( entry )` | `string` | Returns the resolved URL for one entry. |
| `tags( entry )` | `string` | Full `<link>` / `<script>` HTML. Vite: aggregates CSS + module preloads. Manifest: a single `<script>` or `<link>` based on extension. Optionally inlines critical CSS — see below. |
| `bundle( entry )` | `struct` | `{ js, css[], preload[], criticalCss }` — for callers rendering tags by hand. |
| `criticalCss( eventName )` | `string` | Inline critical CSS body for an event. Empty when disabled, in dev, or no file. |
| `viteClient()` | `string` | `<script type="module" src=".../@vite/client"></script>`. Empty in prod. Deduped per request. |
| `isHot()` | `boolean` | True when Vite's hot file exists. |
| `refresh()` | `void` | Clears caches for this module (useful in tests). |

---

## Configuration

The Quick start above is a working starter. Below is every setting with
its default — set only the keys you need to change.

| Setting | Default | Description |
| --- | --- | --- |
| `driver` | `"auto"` | `"vite"`, `"manifest"`, or `"auto"`. Auto picks Vite when a hot file or Vite-shaped manifest is present, otherwise the flat-manifest driver. |
| `manifestPath` | `"/includes/build/.vite/manifest.json"` | Path to the bundler's manifest JSON. |
| `buildPath` | `"/includes/build"` | URL prefix where built assets live (Vite driver). |
| `hotFilePath` | `"/includes/hot"` | Path to Vite's hot file. Its presence enables dev-mode rendering. |
| `devServerUrl` | `""` | Dev-server URL fallback when the hot file is empty. |
| `devMode` | `false` | Enables hot-file polling. Turn on in your dev environment. |
| `renderModulePreload` | `true` | Emit `<link rel="modulepreload">` for imported JS chunks. |
| `includeImportedCss` | `true` | Walk imported chunks for `.css` and emit `<link rel="stylesheet">`. |
| `prependModuleRoot` | `true` | Flat-manifest only. Prepend the module root to resolved URLs. |
| `prependPath` | `"/includes"` | Flat-manifest only. Path prefix prepended to resolved URLs. |
| `cache.enabled` | `true` | Cache parsed manifests in memory. |
| `cache.devCheckInterval` | `2000` | Hot-file recheck cadence in dev, in ms. `0` = every request; `-1` = never (treat dev like prod). |
| `criticalCss.enabled` | `false` | Opt-in critical-CSS inlining. See section below. |
| `criticalCss.path` | `"/includes/critical"` | Directory containing per-route critical CSS files. |
| `criticalCss.suffix` | `".critical.css"` | Suffix appended to the event name to form the file name. |
| `modules` | `{}` | Per-submodule overrides keyed by module name. See section below. |

Substructs (`cache`, `criticalCss`) merge **key-by-key**, so a partial
override like `cache: { devCheckInterval: 5000 }` keeps the default
`cache.enabled = true`.

---

## Submodule overrides

Configure a submodule from the host app by adding a key under
`mixr.modules.<moduleName>`:

```js
moduleSettings = {
    mixr: {
        driver  : "vite",
        modules : {
            admin : { manifestPath : "/admin/build/.vite/manifest.json" },
            blog  : { driver : "manifest", manifestPath : "/includes/rev-manifest.json" }
        }
    }
};
```

A submodule can also declare its own `mixr` settings in its
`ModuleConfig.cfc` (`variables.settings.mixr = {...}`). Each module is
self-contained. Settings do **not** cascade from the root app.

---

## Other bundlers (Laravel Mix, ColdBox Elixir, custom flat manifests)

```js
moduleSettings = {
    mixr: {
        driver            : "manifest",
        manifestPath      : "/includes/mix-manifest.json",
        prependModuleRoot : true,
        prependPath       : "/includes"
    }
};
```

```html
<link rel="stylesheet" href="#mixr( '/css/app.css' )#">
<script src="#mixr( '/js/app.js' )#"></script>
```

The legacy 2.x string form (`mixr( "/path" )`) is unchanged and is the
most ergonomic shape for flat manifests. The fluent API works here too if
you prefer consistency across drivers.

---

## Critical CSS (above-the-fold inlining)

A page-speed optimization that inlines a small per-route stylesheet into
`<head>` as a `<style>` block, then async-loads the full stylesheet
(preload + onload swap with `<noscript>` fallback). Pair Mixr with any
tool that emits per-route CSS files —
[`vite-plugin-critical`](https://www.npmjs.com/package/vite-plugin-critical),
[`laravel-mix-critical`](https://github.com/Pomax/laravel-mix-critical),
or your own.

### Enable it

1. Drop per-route files at `includes/critical/<event>.critical.css` —
   e.g. `main.index.critical.css`, `blog.show.critical.css`.
2. Set `criticalCss.enabled = true`.
3. Keep calling `mixr().tags( "resources/js/app.js" )` as before.

### What `tags()` emits

Without critical CSS (default):

```html
<link rel="stylesheet" href="/includes/build/assets/app-abc.css" />
<link rel="modulepreload" href="/includes/build/assets/vendor-def.js" />
<script type="module" src="/includes/build/assets/app-abc.js"></script>
```

With critical CSS enabled and a fixture for the current event:

```html
<style>/* …inlined critical CSS… */</style>
<link rel="preload" as="style" href="/includes/build/assets/app-abc.css"
      onload="this.onload=null;this.rel='stylesheet'" fetchpriority="high" />
<noscript><link rel="stylesheet" href="/includes/build/assets/app-abc.css" /></noscript>
<link rel="modulepreload" href="/includes/build/assets/vendor-def.js" />
<script type="module" src="/includes/build/assets/app-abc.js"></script>
```

When no file exists for the current event, output is byte-for-byte
identical to the no-critical case — Mixr falls through silently.

### Per-call options

Pass via `mixr().tags( entry, { … } )`:

- `criticalEvent` *(default: current event)* — override the auto-detected event name.
- `skipCritical` *(default: `false`)* — force standard output for this call.
- `nonce` *(default: `""`)* — CSP nonce applied to both the `<style>` and the preload `<link>`.

> **Dev note:** Critical CSS is always skipped while Vite's hot file is
> present, because HMR injects CSS through JS. To preview production
> behavior locally, build with your production-build command (e.g.
> `npm run prod`).

For per-request dedupe across multiple `tags()` calls, advanced render
patterns, and the `</style>` safety check, see [`AGENTS.md`](AGENTS.md).

---

## Upgrade guide: 2.x → 3.0

3.0 is **non-breaking for the legacy string form**. Existing apps that
call `mixr( "/js/app.js" )` continue to work — the default
`driver: "auto"` falls back to the flat-manifest driver when no Vite
manifest or hot file is present.

What's new:

- **Driver setting**: `driver = "vite" | "manifest" | "auto"` (default `auto`).
- **Vite settings**: `buildPath`, `hotFilePath`, `devServerUrl`, `devMode`,
  `renderModulePreload`, `includeImportedCss`, `cache.devCheckInterval`.
- **Fluent API**: `mixr().path()` / `.tags()` / `.bundle()` / `.criticalCss()` /
  `.viteClient()` / `.isHot()` / `.refresh()`.
- **Critical CSS** (opt-in): inline + preload-swap rendering with
  `<noscript>` fallback. Drop per-route files at
  `includes/critical/<event>.critical.css`.
- **Submodule settings are self-contained.** Earlier 3.0 drafts cascaded
  "behavioral" keys (`devMode` etc.) from the host to submodules; 3.0
  final drops the cascade. Configure each submodule explicitly, or via
  `mixr.modules.<name>`. See [`AGENTS.md`](AGENTS.md).

The default Vite manifest path is `/includes/build/.vite/manifest.json`.
For Mix/Elixir apps upgrading without switching bundlers, point
`manifestPath` at the existing manifest:

```js
mixr = {
    driver       : "manifest",   // or "auto"
    manifestPath : "/includes/mix-manifest.json"
};
```

---

## About the author

Mixr is developed by [Angry Sam Productions](https://www.angrysam.com).
Pull requests, issues, and ideas welcome.
