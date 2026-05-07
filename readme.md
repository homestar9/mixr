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
| `tags( entry )` | `string` | Full `<link>` / `<script>` HTML. Vite: aggregates CSS + module preloads. Manifest: single `<script>` or `<link>` based on extension. |
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

Settings cascade: explicit call args win → submodule overrides → root settings →
defaults.

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
