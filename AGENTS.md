# AGENTS.md

This file provides guidance to when working with code in this repository. It is meant to be a living document and should be updated by the LLM when it makes notable changes to the codebase, functionality, patterns, or when it identifies important information that should be documented for future maintainers.

## What this is

Mixr is a ColdBox module (CFML) that resolves static asset paths through either a flat src→dist manifest (Laravel Mix, ColdBox Elixir, custom bundlers) **or** a Vite manifest, with optional Vite dev-server hot reload. It can also output critical CSS based on convention. It is published to ForgeBox as `mixr` and consumed by ColdBox apps via `box install mixr`. The module registers a global `mixr()` helper that handlers/views call to resolve asset paths or render full tag sets.

## Common commands

All commands are run via [CommandBox](https://commandbox.ortusbooks.com/) (`box`). There is no Node/npm tooling in this repo.

```bash
# install dev deps (TestBox, cfformat, etc.) for the package and the test harness
box run-script install:dependencies

# start an engine — port 60299, webroot is test-harness/
box run-script start:lucee5      # also: start:lucee6, start:2018, start:2021, start:2023
box server open                  # open the running server in a browser

# stop / forget / logs follow the same pattern
box run-script stop:lucee5
box run-script logs:lucee5
box run-script forget:lucee5

# run the full TestBox suite in the browser (after the server is running)
# http://localhost:60299/tests/runner.cfm
# Plain-text output:
# http://localhost:60299/tests/runner.cfm?reporter=text

# run a single bundle/spec via URL params
# http://localhost:60299/tests/runner.cfm?bundles=tests.specs.unit.drivers.ViteDriverTest
# http://localhost:60299/tests/runner.cfm?directory=tests.specs.unit

# release / build
box run-script build:module    # produces distributable artifact
box run-script release         # runs build/release.boxr recipe
```

A `start:boxlang` / `stop:boxlang` script exists but BoxLang is currently unverified (TestBox runner returns 500 under BoxLang 1.13; cause unknown). Skip BoxLang unless investigating it specifically.

The harness server aliases `/moduleroot/mixr` to the repo root (`../`) so the test app can `import` the module under development without a separate install. Don't change that alias — `test-harness/config/Coldbox.cfc` registers the module under the harness via `invocationPath = "moduleroot"`.

## Architecture (3.0)

The 3.0 codebase is a small driver architecture behind one facade. Understanding the four layers is the only non-obvious thing here.

### Layer 1 — `ModuleConfig.cfc` (repo root)

What ColdBox loads. It:

- Declares the WireBox mappings: `Mixr@mixr`, `MixrScope@mixr`, `ManifestStore@mixr`, `HotFileWatcher@mixr`, `TagRenderer@mixr`, `ManifestDriver@mixr`, `ViteDriver@mixr`.
- Registers `helpers/Mixins.cfm` as an `applicationHelper` (this is what makes `mixr()` available everywhere).
- Defines the default settings struct: `driver`, `manifestPath`, `buildPath`, `hotFilePath`, `devServerUrl`, `devMode`, `renderModulePreload`, `includeImportedCss`, `prependModuleRoot`, `prependPath`, `cache.{enabled, devCheckInterval}`, `modules`.

### Layer 2 — `helpers/Mixins.cfm`

Defines the global `mixr()` UDF. Call shapes:

```cfml
mixr().path( "resources/js/app.js" )                      // fluent, current module — single URL string
mixr().bundle( "resources/js/app.js" )                    // fluent — { js, css[], preload[], criticalCss } struct
mixr().tags( "resources/js/app.js" )                      // fluent — fully-rendered HTML
mixr().criticalCss()                                      // fluent — inline critical CSS body for current event
mixr().criticalCss( "main.index" )                        // fluent — inline body for an explicit event (eventName positional)
mixr( moduleName = "admin" ).tags( "resources/js/admin.js" )  // fluent, explicit module
mixr( "/js/app.js" )                                       // legacy 2.x string form
mixr( "/js/admin.js", "admin" )                            // legacy with explicit module
```

Two things to know:

- It defaults `moduleName` to `controller.getRequestService().getContext().getCurrentModule()` so calls from inside a submodule auto-target that module's config.
- It lazy-caches the singleton service into `variables.mixrService` on first call to skip a WireBox lookup on every asset reference (`mixr()` gets called many times per request).

### Layer 3 — `models/Mixr.cfc` (facade) + `models/MixrScope.cfc`

`Mixr.cfc` is the singleton facade. It does **not** do any manifest parsing itself anymore — it picks a driver per module and delegates. The core state is:

- `variables._scopes` — `MixrScope` instance per moduleName. `forModule()` is O(1) after first call. A `MixrScope` is a 2-property pointer (service + moduleName) that forwards fluent calls back into the service with the bound moduleName.
- `variables._drivers` — driver instance per moduleName. First call to `driverFor()` resolves config, picks `ViteDriver` or `ManifestDriver`, and pins it. Every subsequent call is a struct lookup + delegate.
- `variables._submoduleOwnSettings` — cache of each submodule's own `mixr` settings struct (lazy-loaded on first reference, pinned for app life).
- `viteClient()` per-request dedupe via RequestContext private values: `event.setPrivateValue("mixr:viteClientRendered:#moduleName#", true)`.

**Settings resolution in `effectiveSettings()`** — every module is self-contained; there is **no cascade**. Settings resolve via a single chain (lowest to highest priority):

1. **System defaults** — declared in mixr's `ModuleConfig.cfc` (mirrored in `Mixr.cfc`'s private `systemDefaults()` helper).
2. **Module's own settings** — for the root, `moduleSettings.mixr.*`. For a submodule, `variables.settings.mixr.*` from its own `ModuleConfig.cfc` (lazy-loaded via `coldbox:moduleSettings:<name>` DSL, cached in `_submoduleOwnSettings`).
3. **Host overrides** — `moduleSettings.mixr.modules.<name>.*` from the root app's config. Only mechanism by which one module's config affects another. Wins per-key.

Substructs (`cache`, `criticalCss`) are merged **key-by-key** at each tier (via `mergeInto()`), not replaced wholesale — so a partial override like `{ cache: { devCheckInterval: 5000 } }` keeps the default `cache.enabled = true`.

The `modules` key is stripped from any module's effective settings — it is a top-level routing concept, not part of any module's per-module config.

**Don't reintroduce a cascade.** The old "behavioral keys cascade from root" design was removed because it surprised installed-from-ForgeBox modules (a host's `devMode = true` would force a third-party admin module to try emitting Vite dev-server URLs even though that module didn't ship a Vite dev server). The current design favors predictability over the convenience of "set `devMode` once."

`Mixr.cfc` does **not** extend `coldbox.system.FrameworkSupertype`. Submodule settings come from the WireBox ColdBox DSL above. Don't reintroduce the inheritance.

Driver picking in `resolveDriverName()`:

- `driver: "vite"` → `ViteDriver`
- `driver: "manifest"` → `ManifestDriver`
- `driver: "auto"` (default) → Vite if a hot file exists, OR if the manifest's first value is a struct with a `file` key (Vite shape); otherwise `ManifestDriver`.
- Anything else throws `InvalidDriver`.

Backward-compat: `Mixr.get(asset, moduleName)` is preserved as an alias for `path()`.

### Layer 4 — drivers + support singletons

**`models/drivers/AbstractDriver.cfc`** holds the per-driver state every driver needs: `settings`, `moduleRoot`, the support collaborators, and four derived caches (`_paths`, `_bundles`, `_tags`, `_criticalCache`). It also subscribes to `ManifestStore.onReload(absoluteManifestPath, callback=clearCaches)` so that a hot-reloaded manifest invalidates the driver's derived caches automatically. Every driver extends this. Also exposes `readCriticalCss(eventName)` — reads the per-route critical CSS file (under `settings.criticalCss.path` joined with `eventName + settings.criticalCss.suffix`), caches the contents per event with dev-mode mtime throttling, and rejects files containing literal `</style>` (throws `MalformedCriticalCss`). Returns `""` when disabled, in dev (`isHot()`), no event, or file missing — so drivers fall through to standard rendering.

**`models/drivers/ManifestDriver.cfc`** — flat src→dist lookup with optional `prependModuleRoot` / `prependPath`. `prependPath` is flat-manifest only; `prependModuleRoot` is honored by **both** drivers (see ViteDriver below). Throws `ManifestAssetNotFound` for unknown keys. `isHot()` is always false; `viteClient()` is always empty.

**`models/drivers/ViteDriver.cfc`** — Vite manifest. Two modes:

- **Production** (`isHot()==false`): Looks up the entry, walks `imports[]` recursively, collecting `css[]` (when `includeImportedCss`) and imported chunk JS files (when `renderModulePreload`). Returns a normalized bundle: `{ js, css[], preload[], criticalCss }`. Throws `EntryNotFound`. Every emitted asset URL (`path()` and `bundle()`'s `js`/`css[]`/`preload[]`) goes through the private `assetUrl( file )` helper, which builds `joinPath( buildPath, file )` and then — gated by `settings.prependModuleRoot` (default `true`) — prepends `variables.moduleRoot` so a module mounted at `/admin` emits `/admin/includes/build/...`. **`prependPath` is intentionally NOT applied by ViteDriver** — the Vite manifest already encodes each file's path under `buildPath`. The `_paths`/`_bundles` caches need no key change: each driver instance is pinned to one `moduleRoot`.
- **Dev** (hot file present + `devMode=true`): Skips manifest reads. `path()` returns `<devUrl>/<entry>`; `tags()` emits a single dev-server `<script type="module">`. Dev-server URLs are absolute and **never** module-root-prefixed (`assetUrl()` is only reached in the prod branches).

**Bundle's `criticalCss` field is stitched outside the `_bundles` cache.** The cache holds only manifest-derived parts (`js`, `css[]`, `preload[]`); each `bundle()` call returns a fresh struct that copies those cached fields and adds a fresh `readCriticalCss()` read. Critical CSS is event-keyed and mtime-volatile in dev — caching it inside `_bundles` would require event/mtime in the cache key. `readCriticalCss()` has its own throttled mtime cache, so the per-call read is cheap.

**Adobe-CF gotcha in `ViteDriver`:** `walkCss` and `walkPreload` accept their collectors as a struct (`bag = { out: [], seen: {} }`) rather than as separate array/struct params. Adobe CF passes arrays by value, so mutations wouldn't propagate; structs are by reference on every engine. Don't refactor those signatures back to bare arrays.

**`models/support/ManifestStore.cfc`** (singleton) — Owns parsed-manifest caching with double-checked locking under `mixr.manifest.<hash>`. Keys by absolute (`expandPath`'d) path. Production: parse once, pin forever. Dev: throttled mtime recheck via `cache.devCheckInterval` (`0`=every call, `N`=throttle ms, `-1`=never). Drivers register `onReload` callbacks here. Throws `ManifestNotFound` and `MalformedManifest` — preserve those types if you refactor, callers may catch them.

**`models/support/HotFileWatcher.cfc`** (singleton) — Reads Vite's hot file (default `/includes/hot`). Production short-circuits to false without disk I/O. Dev throttles by `cache.devCheckInterval`. URL has trailing slashes stripped.

**`models/support/TagRenderer.cfc`** (singleton) — Pure HTML serialization. Drivers hand it normalized data; it produces `<script>`/`<link>` strings with HTML-escaped attributes. Audit attribute escaping here, not in drivers.

### Per-call flow

```
mixr().tags("resources/js/app.js")
 → Mixins.cfm   (cached service ref + auto-detect moduleName)
 → Mixr.path/tags(entry, moduleName)
 → Mixr.driverFor(moduleName)            ← struct lookup after warmup
 → ViteDriver.tags(entry, options)
 → ViteDriver.bundle(entry, options)     ← cached per (entry, options-hash)
   → AbstractDriver.getManifest()        ← cached in ManifestStore
   → walkCss / walkPreload (struct bag)
 → TagRenderer.viteProductionTags(bundle, attrs)
```

After warmup: one struct lookup, one delegate, one bundle-cache hit, one renderer call. No disk I/O, no manifest parse.

### Per-call flow (critical CSS, prod, file present, first call this request)

```
mixr().tags("resources/js/app.js")  [criticalCss.enabled=true, prod, file present, first call this request]
 → Mixins.cfm   (cached service ref + auto-detect moduleName)
 → Mixr.tags(entry, moduleName, options)
   → resolves currentEvent via try/catch on RequestContext
   → checks/sets per-request "criticalInlined" private value (dedupes inline)
 → Mixr.driverFor(moduleName)            ← struct lookup after warmup
 → ViteDriver.tags(entry, options)
 → ViteDriver.bundle(entry, options)     ← cached per (entry, options-hash)
   → AbstractDriver.getManifest()        ← cached in ManifestStore
   → walkCss / walkPreload (struct bag)
 → AbstractDriver.readCriticalCss(eventName) ← cached + mtime-throttled
 → TagRenderer.viteCriticalProductionTags(inlineCss, bundle, attrs, {nonce})
```

The diff vs. the standard flow above is: (1) Mixr.tags() resolves the current event and per-request inline-dedupe state before delegating; (2) the driver consults `readCriticalCss()` (which returns `""` when off, in dev, file-missing, or not-yet-warmup); (3) the renderer swaps `viteProductionTags()` for `viteCriticalProductionTags()` when `inlineCss` is non-empty. When the file is missing or `criticalCss.enabled=false`, `inlineCss` is `""` and output falls through byte-for-byte to the standard flow above.

### Critical CSS for callers building their own tags

Callers who reach for `bundle()` (rendering their own `<script>`/`<link>`/`<style>` rather than using `tags()`) have two access points to the inline critical CSS body — symmetrical with what `tags()` produces internally:

1. **`bundle().criticalCss`** — a string field on the bundle struct. Empty when `criticalCss.enabled=false`, in dev, no event, or file missing. Same rules as `readCriticalCss()`. Driven by `options.criticalEvent` (auto-detected from RequestContext when omitted) and `options.skipCritical`.
2. **`mixr().criticalCss( eventName, options )`** — standalone fluent method. Returns the same string without forcing a manifest read. Use when you only want the inline body. The first positional arg is the event name (empty default → auto-detect from RequestContext); `options` carries `skipCritical` and `markRendered`. The asymmetry with `bundle()`/`tags()` is intentional: critical CSS is event-keyed, so for `criticalCss()` the event IS the primary identifier — same role `entry` plays in `path()`/`tags()`/`bundle()`. Lives on `Mixr.cfc` and `MixrScope.cfc`; the fluent shape is `mixr().criticalCss( "main.index" )`.

**Per-request dedupe is opt-in for these methods.** `tags()` auto-sets `mixr:criticalInlined:#moduleName#` so a second `tags()` call in the same request suppresses its inline. `bundle()` and `criticalCss()` are pure reads by default — they do NOT touch the flag. Callers combining `criticalCss()` (manual rendering) with a later `tags()` call should pass `options.markRendered = true` on the `criticalCss()` call (e.g. `mixr().criticalCss( "main.index", { markRendered: true } )`) so `tags()` will suppress its inline. The flag is only set when the returned string is non-empty.

The `bundle()` method does NOT accept `markRendered` — bundle is a pure data shape. If you want both the data and the dedupe-mark, call `criticalCss( eventName, { markRendered: true } )` first, then `bundle()`.

## Test harness layout

`test-harness/` is a complete ColdBox 7 app whose only purpose is to exercise Mixr. Submodules each cover a different config convention/driver:

- `modules_app/login/` — Mix-style flat manifest, defaults.
- `modules_app/elixir/` — overrides Mixr in its own `ModuleConfig.cfc` (`variables.settings.mixr = {...}`) for the Elixir `rev-manifest.json` convention.
- `modules_app/fooModule/` — overrides Mixr from the parent app's `config/Coldbox.cfc` via `moduleSettings.mixr.modules.fooModule`. The "configure submodule from the host" pattern.
- `modules_app/vite/` — Vite manifest, production mode.
- `modules_app/viteSpa/` — Vite manifest with a hot file, exercises dev-mode rendering.

When adding tests for new behavior, mirror the relevant style — each goes through a different code path in `effectiveSettings()` and the lazy submodule-settings load.

### Why the harness force-loads renderer helpers

`test-harness/config/Coldbox.cfc`'s `afterAspectsLoad` calls `controller.getRenderer().loadApplicationHelpers( force = true )` after `registerAndActivateModule`. **Don't remove this line** — view-side `mixr()` calls will start failing with "No matching function [MIXR]".

Why it's needed: ColdBox's `LoaderService.startup()` runs `activateAllModules()` → `Renderer.startup()` → `announce("afterAspectsLoad")` in that fixed order (`coldbox/system/web/services/LoaderService.cfc` lines 88-102). The renderer is a singleton and only loads `applicationHelper` once during `startup()`. Real apps install mixr conventionally (`modules/` or `modules_app/`) so its helper is registered during `activateAllModules()` and the renderer picks it up. This harness intentionally registers the module-under-test programmatically from `afterAspectsLoad` (so the same harness can test any module via `request.MODULE_NAME`) — by then the renderer has already finished loading helpers, so without the forced reload mixr's helper never reaches view scope. Handlers still work because `EventHandler.onHandlerDIComplete` re-runs `loadApplicationHelpers()` per request.

This is a harness quirk, not a mixr bug. Do not push the forced reload into `mixr/ModuleConfig.cfc` — it would mask the harness ordering issue and add a no-op call to every consuming app.

### Test layout

- `tests/specs/unit/drivers/` — `ManifestDriverTest`, `ViteDriverTest`. Construct drivers directly with mocked support objects. Use this for pure logic.
- `tests/specs/unit/support/` — `ManifestStoreTest`, `HotFileWatcherTest`, `TagRendererTest`.
- `tests/specs/integration/MixrIntegrationTest.cfc` — end-to-end through the live ColdBox app and the global `mixr()` helper.

## Engine support

Last verified passing **140/140 specs on Lucee 5.4.8.2** (full suite, after the `prependModuleRoot` Vite fix added 8 `ViteDriverTest` specs). The other supported engines below were last verified on the `criticalCss` baseline — **re-verify them before merging** (the `prependModuleRoot` change has only been run on Lucee 5 so far):

- Lucee 5.4.8.2 — ✓ 140/140
- Lucee 6.2.6.19 — re-verify
- Adobe ColdFusion 2018, 2021, 2023 — re-verify

BoxLang is currently unverified (test runner returns 500 under 1.13; root cause not yet known).

### Cross-engine portability notes

- **Adobe CF passes arrays by value.** Mutating helper functions must accept their collectors via a struct (which is by reference on every engine). See `ViteDriver.walkCss`/`walkPreload`.
- **Lucee 5 `var url`** collides with the URL scope. Don't use `url` as a local variable name in code that runs on Lucee 5.
- **Lucee 5** doesn't support `ltrim(x, "/")` with a custom char. Use `reReplace(x, "^/+", "")` (which is what `ViteDriver` does for entry normalization).
- Prefer `struct.keyExists("k")` over the Elvis operator `?:` for cross-engine struct access.

## Code style

- `cfformat` is the source of truth — run `box run-script format` before committing. Config: `.cfformat.json`.
- `.cflintrc` is configured but not wired into a script.
- The codebase uses `component { ... }` script syntax everywhere. The one exception is `helpers/Mixins.cfm`, which must be a `.cfm` file because ColdBox `applicationHelper` registration loads it as a template.
- Every method (public and private) carries a javadoc block with `@param` lines for each argument. Match that style when adding methods.

## Backward-compatibility contract

The 3.0 release is non-breaking for the 2.x string form of `mixr()`. Specifically:

- `mixr( asset )` and `mixr( asset, moduleName )` continue to return a resolved path string.
- Apps with no Mixr configuration changes will get `driver: "auto"`, which falls back to the manifest driver when their existing flat manifest is present and no Vite hot file/manifest exists.
- The exception types `ManifestNotFound`, `ManifestAssetNotFound`, `EntryNotFound`, `MalformedManifest`, `InvalidDriver`, and `MalformedCriticalCss` are part of the contract — preserve types if refactoring throw sites.
- `Mixr.get(asset, moduleName)` is preserved as an alias for `path()`.

## Branch context

The default working branch follows GitFlow (`develop` integration, `master` releases). Current focus is the 3.0 release on `feature/add-vite-support`.

## Code Formatting

Do not run `run-script format` or `cfformat` on the codebase. I will run manually.

## Documentation

The documentation is located in the root README.md file. It is written in Markdown and should be updated whenever there are notable changes to the codebase, functionality, patterns, or when important information is identified that should be documented for future maintainers. The file should be written in plain english and should be optimized for developers who are new to the codebase. Avoid too much technical jargon and try to explain concepts in a simple way. Use examples and code snippets to illustrate points when necessary. The documentation should be clear, concise, and easy to understand. Avoid using em-dashes (—) in the documentation unless absolutely necessary for clarity, as they can be difficult to read in plain text form. Use regular dashes (-) instead for better readability.
