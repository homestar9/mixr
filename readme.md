# Mixr

![Mixr Logo](https://github.com/homestar9/mixr/blob/master/mixr-logo.webp?raw=true)

**Mixr** takes logical asset paths like `resources/js/app.js`, looks up the
hashed file your bundler emitted, and renders the `<script>` / `<link>`
tags for you.

It works with **Vite** (production manifest plus dev-server hot reload),
**Webpack**, **Laravel Mix**, **ColdBox Elixir**, or any flat-key manifest
you want to point it at. The `mixr()` helper is available everywhere:
handlers, layouts, views, interceptors.

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
    #mixr().viteClient()# <!-- ignored when devMode is false -->
    #mixr().tags( "resources/js/app.js" )# <!-- css + preload + module script -->
</head>
<body>...</body>
</html>
```

That's it. In **dev**, Mixr sees Vite's hot file and emits dev-server URLs
plus `@vite/client`. In **prod**, it reads `manifest.json` and emits the
hashed `<link rel="stylesheet">`, `<link rel="modulepreload">`, and
`<script type="module">` tags, pulling in CSS chunks and module preloads
for you.

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

Skip `moduleName` and Mixr figures out which module is handling the
current request, so submodule configs just work.

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

Quick start covers the working defaults. Here's the full list, in case
you need to tune something. You only have to set the keys you're actually
changing.

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

Heads up: the `cache` and `criticalCss` substructs merge **key-by-key**.
If you override just `cache: { devCheckInterval: 5000 }`, the default
`cache.enabled = true` still applies.

---

## Submodule overrides

Need different settings per submodule? Drop them under
`mixr.modules.<moduleName>` in the host app:

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

Submodules can also bring their own settings via
`variables.settings.mixr = {...}` in their own `ModuleConfig.cfc`. Each
module's config is independent: the root app's settings don't cascade
down.

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

If you're coming from 2.x, the old string form (`mixr( "/path" )`) still
works and honestly reads nicest with flat manifests. Use the fluent API
if you want consistency across drivers.

---

## Critical CSS (above-the-fold inlining)

Critical CSS is one of those page-speed wins that's still worth doing in
2026. The idea: inline the above-the-fold styles into `<head>` as a
`<style>` block, then async-load the rest (preload + onload swap, with a
`<noscript>` fallback for JS-off). Mixr handles the rendering side. Pair
it with any tool that emits per-route CSS files:
[`vite-plugin-critical`](https://www.npmjs.com/package/vite-plugin-critical),
[`laravel-mix-critical`](https://github.com/Pomax/laravel-mix-critical),
or roll your own.

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

If there's no critical file for the current event, Mixr falls through
silently and you get the exact same output as if critical CSS were off.
No surprises.

### Per-call options

Pass via `mixr().tags( entry, { … } )`:

- `criticalEvent` *(default: current event)* — override the auto-detected event name.
- `skipCritical` *(default: `false`)* — force standard output for this call.
- `nonce` *(default: `""`)* — CSP nonce applied to both the `<style>` and the preload `<link>`.

> **Dev note:** Critical CSS gets skipped whenever Vite's hot file is
> around. HMR is already injecting CSS through JS, so inlining stale
> critical files would just fight it. Want to preview the production
> behavior locally? Run a production build (`npm run prod` or whatever
> your project uses).

For per-request dedupe across multiple `tags()` calls, advanced render
patterns, and the `</style>` safety check, see [`AGENTS.md`](AGENTS.md).

---

## Upgrade guide: 2.x → 3.0

Good news first: if you're on 2.x and calling `mixr( "/js/app.js" )`, you
don't have to change anything. The default `driver: "auto"` falls back to
the flat-manifest driver when no Vite manifest or hot file is around, so
your existing app keeps working.

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
  "behavioral" keys (`devMode` and friends) from the host into
  submodules. The final release drops that. Configure each submodule
  explicitly, or use `mixr.modules.<name>` from the host. See
  [`AGENTS.md`](AGENTS.md) for the resolution chain.

The Vite manifest default is `/includes/build/.vite/manifest.json`. If
you're upgrading a Mix or Elixir app and not switching bundlers, just
point `manifestPath` at the manifest you already have:

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
