# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mixr is a ColdBox module (CFML) that resolves static asset paths through either a flat src→dist manifest (Laravel Mix, ColdBox Elixir, custom bundlers) **or** a Vite manifest, with optional Vite dev-server hot reload. It is published to ForgeBox as `mixr` and consumed by ColdBox apps via `box install mixr`. The module registers a global `mixr()` helper that handlers/views call to resolve asset paths or render full tag sets.

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

# formatting (cfformat) — run before committing
box run-script format          # apply formatting in place
box run-script format:check    # CI-style check, no writes
box run-script format:watch    # watch mode

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

Defines the global `mixr()` UDF. Three call shapes:

```cfml
mixr().path( "resources/js/app.js" )                      // fluent, current module
mixr( moduleName = "admin" ).tags( "resources/js/admin.js" )  // fluent, explicit module
mixr( "/js/app.js" )                                       // legacy 2.x string form
mixr( "/js/admin.js", "admin" )                            // legacy with explicit module
```

Two things to know:

- It defaults `moduleName` to `controller.getRequestService().getContext().getCurrentModule()` so calls from inside a submodule auto-target that module's config.
- It lazy-caches the singleton service into `variables.mixrService` on first call to skip a WireBox lookup on every asset reference (`mixr()` gets called many times per request).

### Layer 3 — `models/Mixr.cfc` (facade) + `models/MixrScope.cfc`

`Mixr.cfc` is the singleton facade. It does **not** do any manifest parsing itself anymore — it picks a driver per module and delegates. Three caches and one settings cascade are the core of it:

- `variables._scopes` — `MixrScope` instance per moduleName. `forModule()` is O(1) after first call. A `MixrScope` is a 2-property pointer (service + moduleName) that forwards fluent calls back into the service with the bound moduleName.
- `variables._drivers` — driver instance per moduleName. First call to `driverFor()` resolves config, picks `ViteDriver` or `ManifestDriver`, and pins it. Every subsequent call is a struct lookup + delegate.
- `viteClient()` per-request dedupe via RequestContext private values: `event.setPrivateValue("mixr:viteClientRendered:#moduleName#", true)`.

Settings cascade in `effectiveSettings()`: cached per-module once, and built by `duplicate(rootSettings)` → strip `modules` → merge `cache` defaults → overlay `settings.modules[moduleName]` (loaded lazily via `wirebox.getInstance(dsl="coldbox:moduleSettings:#name#")`). The `modules` key itself is never inherited.

`Mixr.cfc` does **not** extend `coldbox.system.FrameworkSupertype`. Submodule settings come from the WireBox ColdBox DSL above. Don't reintroduce the inheritance.

Driver picking in `resolveDriverName()`:

- `driver: "vite"` → `ViteDriver`
- `driver: "manifest"` → `ManifestDriver`
- `driver: "auto"` (default) → Vite if a hot file exists, OR if the manifest's first value is a struct with a `file` key (Vite shape); otherwise `ManifestDriver`.
- Anything else throws `InvalidDriver`.

Backward-compat: `Mixr.get(asset, moduleName)` is preserved as an alias for `path()`.

### Layer 4 — drivers + support singletons

**`models/drivers/AbstractDriver.cfc`** holds the per-driver state every driver needs: `settings`, `moduleRoot`, the support collaborators, and three derived caches (`_paths`, `_bundles`, `_tags`). It also subscribes to `ManifestStore.onReload(absoluteManifestPath, callback=clearCaches)` so that a hot-reloaded manifest invalidates the driver's derived caches automatically. Every driver extends this.

**`models/drivers/ManifestDriver.cfc`** — flat src→dist lookup with optional `prependModuleRoot` / `prependPath`. Throws `ManifestAssetNotFound` for unknown keys. `isHot()` is always false; `viteClient()` is always empty.

**`models/drivers/ViteDriver.cfc`** — Vite manifest. Two modes:

- **Production** (`isHot()==false`): Looks up the entry, walks `imports[]` recursively, collecting `css[]` (when `includeImportedCss`) and imported chunk JS files (when `renderModulePreload`). Returns a normalized bundle: `{ js, css[], preload[] }`. Throws `EntryNotFound`.
- **Dev** (hot file present + `devMode=true`): Skips manifest reads. `path()` returns `<devUrl>/<entry>`; `tags()` emits a single dev-server `<script type="module">`.

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

Adobe ColdFusion 2021 has a TestBox stub bug where multiple `execute()` calls inside one `it()` produce `DynamicDuplicateFunctionDefinitionException`. Consolidate to a single `execute()` per spec when an integration test needs to drive a handler — see the global-helper spec in `MixrIntegrationTest.cfc`.

## Engine support

Verified passing 40/40 specs on:

- Lucee 5.4.8.2
- Lucee 6.2.6.19
- Adobe ColdFusion 2018, 2021, 2023

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
- The exception types `ManifestNotFound`, `ManifestAssetNotFound`, and (new) `EntryNotFound`, `MalformedManifest`, `InvalidDriver` are part of the contract — preserve types if refactoring throw sites.
- `Mixr.get(asset, moduleName)` is preserved as an alias for `path()`.

## Branch context

The default working branch follows GitFlow (`develop` integration, `master` releases). Current focus is the 3.0 release on `feature/add-vite-support`.
