# Changelog

All notable changes to this project will be documented in this file.

----

## [3.0.0] => 2026-06-19

* **New** — First-class **Vite** support: production manifest resolution, dev-server hot reload via the Vite hot file, CSS aggregation across imported chunks, `<link rel="modulepreload">` emission, and `@vite/client` injection (deduped per request).
* **New** — Driver architecture: `driver: "vite" | "manifest" | "auto"`. The `auto` driver (default) picks Vite when it sees a hot file or a Vite-shaped manifest, otherwise falls back to the flat-manifest driver.
* **New** — Fluent helper API: `mixr().path()`, `mixr().tags()`, `mixr().bundle()`, `mixr().viteClient()`, `mixr().isHot()`, `mixr().refresh()`. Pass `moduleName` to scope to a different submodule: `mixr( moduleName = "admin" ).tags( "…" )`.
* **New** settings: `buildPath`, `hotFilePath`, `devServerUrl`, `devMode`, `renderModulePreload`, `includeImportedCss`, `cache.enabled`, `cache.devCheckInterval`.
* **Settings** — Each module is self-contained; settings do **not** cascade between modules. They resolve in one chain: system defaults → the module's own settings (`moduleSettings.mixr.*` for the root app, or `variables.settings.mixr.*` from a submodule's own `ModuleConfig.cfc`) → host overrides under `moduleSettings.mixr.modules.<name>.*` (the only mechanism by which one module's config affects another). A host's `devMode` no longer leaks into installed submodules.
* **Performance** — Drivers and module-bound scopes are cached per module on the singleton service; per-request work is a struct lookup plus a delegate call. Hot-file polling is throttled by `cache.devCheckInterval`.
* **Compat** — The legacy `mixr( asset )` and `mixr( asset, moduleName )` string forms are unchanged, and the `auto` driver still resolves to the flat-manifest driver when no Vite manifest/hot file is present. **One upgrade action:** the default `manifestPath` moved from `/includes/mix-manifest.json` (2.x) to the Vite path `/includes/build/.vite/manifest.json`. Apps that relied on the 2.x default must now set `manifestPath` explicitly (point it at your existing manifest); apps that already set `manifestPath`, or that use the Vite default, need no changes. If you miss it, the `ManifestNotFound` error names this exact fix.
* **Internals** — `Mixr.cfc` no longer extends `coldbox.system.FrameworkSupertype`; submodule settings are looked up via the `coldbox:moduleSettings:<name>` WireBox DSL.
* **Engines** — Verified on Lucee 5, Lucee 6, Adobe ColdFusion 2023, and BoxLang 1.14. (Adobe ColdFusion 2018 and 2021 are no longer supported.)

## [2.0.1] => 2026-05-07

* **License** - Added license file to the project

## [2.0.0] => 2024-05-21

* **Breaking Change** - Updated default configuration to emulate Laravel Mix 6

## [1.0.0] => 2023-03-07

* First release
