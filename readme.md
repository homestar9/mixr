# Mixr

![Mixr Logo](https://github.com/homestar9/mixr/blob/master/mixr.svg?raw=true)

**Mixr** is a flexible static asset helper for ColdBox apps. It resolves logical
asset paths (`resources/js/app.js`) into the real, hashed files your bundler
emits, and — new in 3.0 — speaks fluent **Vite**: dev-server hot reload, CSS
aggregation, module preload tags, and the works.

Out of the box Mixr supports:

- **Vite** (production manifests + dev server hot reload)
- **Laravel Mix** (`mix-manifest.json`)
- **ColdBox Elixir** (`rev-manifest.json`)
- Any custom flat-key manifest

It registers a global `mixr()` helper available in every handler, layout, view,
and interceptor.

---

## Installation

```bash
box install mixr
```

---

## Quick start

### Vite (3.0)

`config/Coldbox.cfc`:

```js
moduleSettings = {
    mixr: {
        driver       : "vite",       // or "auto"
        manifestPath : "/includes/build/.vite/manifest.json",
        buildPath    : "/includes/build",
        hotFilePath  : "/includes/hot",
        devMode      : getSystemSetting( "ENVIRONMENT", "production" ) eq "development"
    }
};
```

In a layout:

```html
<!DOCTYPE html>
<html>
<head>
    #mixr().viteClient()#                              <!-- no-op in prod -->
    #mixr().tags( "resources/js/app.js" )#             <!-- css + preload + module script -->
</head>
<body>...</body>
</html>
```

In dev (when Vite has written `/includes/hot`) Mixr emits dev-server URLs and
`@vite/client`. In prod it reads `manifest.json` and emits the hashed `<link>`
and `<script type="module">` tags, with imported chunks preloaded and any CSS
chunk references included automatically.

### Laravel Mix / ColdBox Elixir / custom (drop-in 2.x replacement)

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
<script src="#mixr( '/js/app.js' )#"></script>
<link rel="stylesheet" href="#mixr( '/css/app.css' )#">
```

### Auto-detect (default)

```js
moduleSettings = { mixr: { driver: "auto" } };
```

`driver: "auto"` (the default) picks Vite when it sees a hot file or a Vite-
shaped manifest, and falls back to the flat-manifest driver otherwise. This
makes Mixr safe to install in an app that hasn't decided yet.

---

## The `mixr()` helper

Three call shapes:

```cfm
<!-- 1. Fluent, current module -->
#mixr().path( "resources/js/app.js" )#
#mixr().tags( "resources/js/app.js" )#
#mixr().viteClient()#
#mixr().isHot()#

<!-- 2. Fluent, explicit module -->
#mixr( moduleName = "admin" ).tags( "resources/js/admin.js" )#

<!-- 3. Legacy 2.x string form -->
#mixr( "/js/app.js" )#
#mixr( "/js/admin.js", "admin" )#
```

When `moduleName` is omitted, Mixr auto-detects the module handling the current
request, so submodule configs are picked up without any extra wiring.

### Methods on the fluent scope

| Method | Returns | Notes |
| --- | --- | --- |
| `path( entry )` | `string` | Resolved URL for a single entry. |
| `tags( entry )` | `string` | Full `<link>` / `<script>` HTML. Vite: aggregates CSS + module preloads. Manifest: single `<script>` or `<link>` based on extension. With optional inline-critical-CSS rendering when `criticalCss.enabled` is true — see "Critical CSS" below. |
| `bundle( entry )` | `struct` | `{ entry, css[], preload[], devUrl, hot }`. Use when you need to render tags yourself. |
| `viteClient()` | `string` | `<script type="module" src=".../@vite/client"></script>`. Empty in prod. Deduped per request. |
| `isHot()` | `boolean` | True when the Vite dev server hot file exists. |
| `refresh()` | `void` | Clears caches for this module. Useful in tests. |

The legacy service method `mixr().get( asset )` is preserved as an alias for
`path()`.

---

## Configuration

All settings, with defaults:

```js
mixr = {
    // "vite" | "manifest" | "auto"
    driver              : "auto",

    // Vite (also used by auto-detection)
    manifestPath        : "/includes/build/.vite/manifest.json",
    buildPath           : "/includes/build",
    hotFilePath         : "/includes/hot",
    devServerUrl        : "",                 // fallback when hot file is empty
    devMode             : false,              // turn on hot-file polling
    renderModulePreload : true,               // emit <link rel="modulepreload">
    includeImportedCss  : true,               // walk imported chunks for .css

    // Manifest driver (Mix / Elixir / custom) — preserved from 2.x
    prependModuleRoot   : true,
    prependPath         : "/includes",

    // Caching
    cache : {
        enabled          : true,
        // devMode hot-file recheck:
        //   0  -> recheck every request
        //   N  -> throttle to once per N ms
        //  -1  -> never recheck (treat dev like prod)
        devCheckInterval : 2000
    },

    // Critical CSS (above-the-fold inlining) — see "Critical CSS" section below
    criticalCss : {
        enabled : false,                 // OPT-IN
        path    : "/includes/critical",  // module-relative directory
        suffix  : ".critical.css"        // appended to event name
        // Note: critical CSS is always skipped when isHot() — preview locally
        //       with a production build (e.g. `npm run prod`).
    },

    // Per-submodule overrides (see below)
    modules : {}
};
```

### Per-submodule configuration

Two equivalent ways. Pick whichever fits the codebase.

**A. From the submodule itself** — add a `mixr` key to the module's
`variables.settings` in its `ModuleConfig.cfc`:

```js
// modules_app/admin/ModuleConfig.cfc
function configure(){
    settings = {
        mixr: {
            driver       : "vite",
            manifestPath : "/includes/build/.vite/manifest.json",
            buildPath    : "/includes/build"
        }
    };
}
```

**B. From the host app** — declare overrides under
`mixr.modules.<moduleName>` in `config/Coldbox.cfc`:

```js
moduleSettings = {
    mixr: {
        driver  : "manifest",
        modules : {
            admin: {
                driver       : "vite",
                manifestPath : "/includes/build/.vite/manifest.json"
            },
            blog: {
                manifestPath : "/includes/rev-manifest.json",
                prependPath  : ""
            }
        }
    }
};
```

### How settings resolve

Each module is self-contained. There is **no cascade** from the root app to
submodules — installing a module from ForgeBox does not inherit your host's
`devMode`, `driver`, or any other key. Settings resolve via a single chain
(lowest to highest priority):

1. **System defaults** — Mixr's built-in fallbacks (declared in mixr's own
   `ModuleConfig.cfc`).
2. **Module's own settings** — for the root app, the values under
   `moduleSettings.mixr.*`. For a submodule, the values its own
   `ModuleConfig.cfc` declares as `variables.settings.mixr.*`.
3. **Host overrides via `modules.<name>`** — `moduleSettings.mixr.modules.<name>.*`
   from the root app's config. This is the *only* mechanism by which one
   module's config affects another. Host overrides win per-key over the
   module's own settings.

Substructs (`cache`, `criticalCss`) are merged key-by-key, so a partial
override like `cache: { devCheckInterval: 5000 }` keeps the default
`cache.enabled = true`.

#### Worked example

```js
moduleSettings = {
    mixr: {
        // Root app's own settings — apply ONLY to the root app.
        driver       : "vite",
        devMode      : true,
        manifestPath : "/some/path/manifest.json",

        // Host overrides — apply ONLY to the named submodule.
        modules : {
            admin : { manifestPath : "/admin/build/.vite/manifest.json" }
        }
    }
};
```

What each module sees:

- **Root app** — `driver=vite, devMode=true, manifestPath=/some/path/manifest.json`
  (its own values, with system defaults filling in unspecified keys like
  `renderModulePreload=true`).
- **`admin` submodule** — host's `manifestPath` override wins; everything
  else falls back to `admin`'s own `ModuleConfig.cfc` settings, which fall
  back to system defaults. `driver` and `devMode` from the root do **NOT**
  reach `admin`.
- **`blog` submodule** (no host override, no own mixr settings) — system
  defaults across the board (`driver=auto`, `devMode=false`, etc.).

If you want `devMode = true` for several internal submodules, declare it
under each `modules.<name>` block explicitly, or in each submodule's own
`ModuleConfig.cfc`. Mixr does not auto-cascade — predictability beats
convenience here, especially for installed-from-ForgeBox modules.

---

## How Vite mode works

In **production** (`isHot() == false`):

1. Mixr reads `manifestPath` once and caches the parsed JSON.
2. For each call, it looks up the entry, then walks `imports[]` recursively to
   collect every CSS chunk (when `includeImportedCss` is true) and every
   imported JS chunk for `<link rel="modulepreload">`.
3. `tags()` returns:
   ```html
   <link rel="stylesheet" href="/includes/build/assets/app.abc123.css">
   <link rel="modulepreload" href="/includes/build/assets/vendor.def456.js">
   <script type="module" src="/includes/build/assets/app.789xyz.js"></script>
   ```

In **development** (`devMode = true` and `/includes/hot` exists):

1. The hot file content is treated as the dev server URL (Vite writes this on
   `vite dev` startup). `devServerUrl` is used as a fallback.
2. `viteClient()` emits `<script type="module" src="<devUrl>/@vite/client"></script>`
   (deduped per request).
3. `tags()` emits a single `<script type="module" src="<devUrl>/<entry>">`.

Hot-file polling is throttled by `cache.devCheckInterval` so it isn't a per-
request disk hit.

---

## Critical CSS (above-the-fold inlining)

A page-speed optimization that inlines a small per-route stylesheet into
`<head>` as a `<style>` block, then async-loads the full stylesheet (preload +
onload swap, with a `<noscript>` fallback). It's still the recommended pattern
in 2026 — Lighthouse's "Eliminate render-blocking resources" audit rewards it.

Mixr is build-agnostic. Pair with any tool that emits per-route CSS files:
[`vite-plugin-critical`](https://www.npmjs.com/package/vite-plugin-critical) for
Vite, [`laravel-mix-critical`](https://github.com/Pomax/laravel-mix-critical)
for Mix/Webpack, or anything else that produces matching files.

### Enabling critical CSS

1. Drop your build's per-route critical CSS files at
   `includes/critical/<event>.critical.css` (the path and suffix are
   configurable). Examples: `main.index.critical.css`, `blog.show.critical.css`.
2. Set `criticalCss.enabled = true` in your `mixr` settings.
3. Keep calling `mixr().tags( "resources/js/app.js" )` exactly as before.

### What `tags()` emits

Without critical CSS (today's behavior, default):

```html
<link rel="stylesheet" href="/includes/build/assets/app-abc.css" />
<link rel="modulepreload" href="/includes/build/assets/vendor-def.js" />
<script type="module" src="/includes/build/assets/app-abc.js"></script>
```

With critical CSS enabled and a fixture file present for the current event:

```html
<style>/* …inlined critical CSS… */</style>
<link rel="preload" as="style" href="/includes/build/assets/app-abc.css"
      onload="this.onload=null;this.rel='stylesheet'" fetchpriority="high" />
<noscript><link rel="stylesheet" href="/includes/build/assets/app-abc.css" /></noscript>
<link rel="modulepreload" href="/includes/build/assets/vendor-def.js" />
<script type="module" src="/includes/build/assets/app-abc.js"></script>
```

When no critical file exists for the current event, output is byte-for-byte
identical to the no-critical case — Mixr falls through silently.

### Convention

The current event is auto-detected from the ColdBox RequestContext via
`event.getCurrentEvent()`. The file lookup is:

```
<criticalCss.path>/<eventName><criticalCss.suffix>
```

Defaults: `path = "/includes/critical"`, `suffix = ".critical.css"`.

So an event of `main.index` resolves to `/includes/critical/main.index.critical.css`
under that module's moduleRoot.

### Per-call options

Pass via `mixr().tags( entry, { … } )`:

- `criticalEvent` *(default: current event)* — override the auto-detected event name.
- `criticalFile`  *(default: `""`)*  — bypass the event/path/suffix lookup with an explicit web path. *(Reserved for future use; resolution is currently event-based.)*
- `skipCritical`  *(default: `false`)* — force standard `tags()` output for this call regardless of settings/files.
- `nonce`         *(default: `""`)*   — CSP nonce, applied to both `<style>` and the preload `<link>`.

### Dev-mode behavior

Critical CSS is **always skipped** when Vite's hot file is present
(`isHot() == true`). HMR injects CSS through JS, and inlining stale critical
files would conflict. To preview production critical-CSS behavior locally,
build with `npm run prod` (or your project's production-build command) and
reload — or temporarily disable HMR.

### Per-request dedupe

When `tags()` is called multiple times in the same request (e.g. you're
loading both an entry CSS and a separate JS bundle), the inline `<style>` is
emitted only on the first call. Later calls in the same request still get
their preload-swap link, but no duplicate `<style>` block.

### Common usage patterns

#### Pattern A — Vite, single entry per page

```html
<head>
    #mixr().viteClient()#
    #mixr().tags( "resources/js/app.js" )#
</head>
```

#### Pattern B — Flat manifest, separate CSS + JS

```html
<head>
    #mixr().tags( "/css/app.css" )#  <!-- inline + preload-swap CSS -->
    #mixr().tags( "/js/app.js" )#    <!-- standard <script>; inline already deduped -->
</head>
```

#### Pattern C — Per-route opt-out

```cfm
<!-- This particular handler/view shouldn't get critical inlining -->
#mixr().tags( "resources/js/app.js", { skipCritical: true } )#
```

#### Pattern D — CSP nonce

```cfm
#mixr().tags( "resources/js/app.js", { nonce: prc.cspNonce } )#
```

#### Pattern E — Submodule opt-in / opt-out via host config

```js
moduleSettings = {
    mixr: {
        modules : {
            // Opt admin in
            admin : { criticalCss : { enabled : true } },
            // Opt blog out (e.g. blog ships critical files but you don't want them in prod)
            blog  : { criticalCss : { enabled : false } }
        }
    }
};
```

### Safety: `</style>` rejection

Mixr rejects critical CSS files that contain the literal string `</style>`
— that would break the inlined `<style>` block and could be an XSS vector.
A malformed file throws `MalformedCriticalCss` so the source build artifact
gets fixed rather than silently producing broken HTML.

---

## Performance notes

Mixr is built to be called many times per page render:

- The singleton service caches one **driver** per module — first call resolves
  config and instantiates a driver, every later call is a struct lookup.
- A bound `MixrScope` is also cached per module — `mixr()` is constant-time
  after warmup.
- Each driver caches resolved paths, parsed manifests, and rendered tag bundles.
- `helpers/Mixins.cfm` caches the WireBox lookup in `variables.mixrService`.

---

## Upgrade guide

### 2.x → 3.0

3.0 is **non-breaking for the legacy string form**. Existing apps that call
`mixr( "/js/app.js" )` continue to work without configuration changes — the
default `driver: "auto"` falls back to the flat-manifest driver when no Vite
manifest or hot file is present.

What changed:

- New `driver` setting: `"vite" | "manifest" | "auto"` (default `auto`).
- New Vite settings: `buildPath`, `hotFilePath`, `devServerUrl`, `devMode`,
  `renderModulePreload`, `includeImportedCss`, `cache.devCheckInterval`.
- New fluent API: `mixr().path()`, `mixr().tags()`, `mixr().viteClient()`,
  `mixr().isHot()`, `mixr().bundle()`, `mixr().refresh()`.
- The default `manifestPath` for Vite is `/includes/build/.vite/manifest.json`.
  If you're upgrading a Mix or Elixir app and want auto-detect, leave the
  manifest setting pointing at your existing manifest:
  ```js
  mixr = {
      driver       : "manifest",   // or "auto"
      manifestPath : "/includes/mix-manifest.json"
  };
  ```
- `mixr()` now also accepts an explicit `moduleName` argument (preserved from
  2.x) and a no-asset fluent form. Old call sites are unaffected.
- **Settings cascade removed.** Earlier 3.0 drafts cascaded "behavioral"
  keys (like `devMode`) from the host app to every submodule. 3.0 final
  drops this — each module is self-contained and the host overrides only
  via `mixr.modules.<name>`. See the "How settings resolve" section above.
  Apps that were relying on the cascade need to either declare the keys
  on each submodule directly or via the host's `modules.<name>` block.
- **Critical CSS support.** `tags()` gains optional inline-critical-CSS
  rendering with async-loaded full stylesheet (preload + onload swap +
  `<noscript>` fallback). Off by default; opt in via `criticalCss.enabled`.
  Build-tooling-agnostic: drop per-route files at
  `includes/critical/<event>.critical.css` and Mixr handles the rest.
  See the "Critical CSS" section above.

### 1.x → 2.x

(Unchanged from 2.0.) Defaults switched to Laravel Mix 6 conventions; ColdBox
Elixir users must set `manifestPath`, `prependPath` explicitly.

---

## Testing

Mixr ships a full test harness covering 5 CFML engines.

```bash
box run-script install:dependencies

box run-script start:lucee5    # or :lucee6, :2018, :2021, :2023
box server open
# navigate to /tests/runner.cfm
```

Run a single bundle:

```
http://localhost:60299/tests/runner.cfm?bundles=tests.specs.unit.drivers.ViteDriverTest
```

The 3.0 release passes 40/40 specs on Lucee 5.4.8.2, Lucee 6.2.6.19, Adobe
ColdFusion 2018, 2021, and 2023.

---

## About the author

Mixr is developed by [Angry Sam Productions](https://www.angrysam.com).
Pull requests, issues, and ideas welcome.
