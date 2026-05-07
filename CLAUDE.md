# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mixr is a ColdBox module (CFML) that resolves static asset paths through a manifest file (Laravel Mix, ColdBox Elixir, or a custom bundler). It is published to ForgeBox as `mixr` and consumed by ColdBox apps via `box install mixr`. The module registers a global `mixr()` helper that handlers/views call to translate a logical asset path into the hashed/versioned distribution path.

## Common commands

All commands are run via [CommandBox](https://commandbox.ortusbooks.com/) (`box`). There is no Node/npm tooling.

```bash
# install dev deps (TestBox, cfformat, etc.) for the package and the test harness
box run-script install:dependencies

# start a CFML engine to run the test harness — port 60299, webroot is test-harness/
box start server-lucee@5.json
box start server-adobe@2018.json
box start server-adobe@2021.json
box server open                        # open the running server in a browser

# run the full TestBox suite in the browser (after the server is running)
# http://localhost:60299/tests/runner.cfm

# run a single bundle/spec via URL params on the runner
# http://localhost:60299/tests/runner.cfm?bundles=tests.specs.unit.MixrTest
# http://localhost:60299/tests/runner.cfm?directory=tests.specs.unit

# formatting (cfformat) — run before committing
box run-script format          # apply formatting in place
box run-script format:check    # CI-style check, no writes
box run-script format:watch    # watch mode

# release / build
box run-script build:module    # produces distributable artifact
box run-script release         # runs build/release.boxr recipe
```

The harness server aliases `/moduleroot/mixr` to the repo root (`../`) so the test app can `import` the module under development without a separate install. Don't change that alias — `test-harness/config/Coldbox.cfc` registers the module under the harness via `invocationPath = "moduleroot"` and depends on it.

## Architecture

The module has three moving parts; understanding how they wire together is the only non-obvious thing here.

**`ModuleConfig.cfc`** (repo root) is what ColdBox loads. It declares the WireBox mapping `Mixr@mixr` → `models/Mixr.cfc`, registers `helpers/Mixins.cfm` as an `applicationHelper` (which is what makes `mixr()` available everywhere), and defines the default settings struct (`manifestPath`, `prependModuleRoot`, `prependPath`, `modules`).

**`helpers/Mixins.cfm`** defines the global `mixr()` UDF. Two things to know:
- It defaults `moduleName` to `controller.getRequestService().getContext().getCurrentModule()` so calls from inside a submodule auto-target that module's manifest.
- It lazy-caches the singleton service into `variables.mixrService` on first call to skip a WireBox lookup on every asset reference (asset helpers get called a lot per request).

**`models/Mixr.cfc`** is the singleton service. Three caches and one settings cascade are the core of it:
- `variables._manifests` — parsed manifest JSON keyed by manifest path. Populated under a named lock (`mixr`) using double-checked locking, so concurrent first-requests don't race on file I/O.
- `variables._cachedPaths` — fully resolved output paths keyed by `hash(serializeJSON(arguments))`. This is the per-call cache; once a `(asset, moduleName, ...)` tuple has been resolved, subsequent calls skip the manifest lookup entirely.
- `settings.modules[moduleName]` — populated lazily on first request from a given submodule. The service reads `getModuleSettings(moduleName).mixr` and stashes it under the parent module's settings struct, so each submodule's config (declared in its own `ModuleConfig.cfc` under `variables.settings.mixr`) is discovered without explicit registration in the parent app.
- Settings cascade in `applyDefaults()`: explicit call args win → then `settings.modules[moduleName][key]` if present → then root `settings[key]`. The `modules` key itself is excluded from the cascade.

A missing manifest throws `ManifestNotFound`; an asset not present in a manifest throws `ManifestAssetNotFound`. Both are typed exceptions — preserve those types if you refactor, callers may catch them.

## Test harness layout

`test-harness/` is a complete ColdBox 7 app whose only purpose is to exercise Mixr. It contains three submodules that each cover a different config convention:

- `modules_app/login/` — uses Mixr defaults (Laravel Mix conventions); module declares an empty `variables.settings`.
- `modules_app/elixir/` — overrides Mixr in its own `ModuleConfig.cfc` (`variables.settings.mixr = {...}`) to use ColdBox Elixir's `rev-manifest.json` convention.
- `modules_app/fooModule/` — overrides Mixr from the parent app's `config/Coldbox.cfc` via `moduleSettings.mixr.modules.fooModule`. This is the "configure submodule from the host" pattern.

When adding tests for new behavior, mirror these three styles — they each go through a different code path in `applyDefaults()` and `settings.modules` lazy-load.

Unit tests live in `test-harness/tests/specs/unit/` and use TestBox's BDD style. `MixrTest.cfc` mocks `settings` directly via `model.$property(...)` so it doesn't depend on a live ColdBox app — keep that pattern for pure unit tests of the service.

## Code style

- `cfformat` is the source of truth — run `box run-script format` before committing. The config is in `.cfformat.json`.
- `.cflintrc` is configured but not wired into a script.
- The codebase uses `component { ... }` script syntax everywhere. The one exception is `helpers/Mixins.cfm`, which must be a `.cfm` file because ColdBox `applicationHelper` registration loads it as a template.

## Branch context

The default working branch follows GitFlow (`develop` is the integration branch, `master` is releases). The current feature branch (`feature/add-vite-support`) suggests work on a Vite manifest convention — Vite's manifest format differs from Laravel Mix's (it's keyed by source path with a nested `{ file, src, isEntry, ... }` value rather than a flat src→dist map), so any Vite work likely needs a new parsing path in `importManifestFile()` or a config flag that switches manifest interpretation.
