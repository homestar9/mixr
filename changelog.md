# Changelog

All notable changes to this project will be documented in this file.

----

## [3.0.0] => 2026-06-19

* **New** — First-class **Vite** support: production manifest resolution, dev-server hot reload via the Vite hot file, CSS aggregation across imported chunks, `<link rel="modulepreload">` emission, and `@vite/client` injection (deduped per request).
* **New** — Driver architecture: `driver: "vite" | "manifest" | "auto"`. The `auto` driver (default) picks Vite when it sees a hot file or a Vite-shaped manifest, otherwise falls back to the flat-manifest driver.
* **New** — Fluent helper API: `mixr().path()`, `mixr().tags()`, `mixr().bundle()`, `mixr().viteClient()`, `mixr().isHot()`, `mixr().refresh()`. Pass `moduleName` to scope to a different submodule: `mixr( moduleName = "admin" ).tags( "…" )`.
* **New** settings: `buildPath`, `hotFilePath`, `devServerUrl`, `devMode`, `renderModulePreload`, `includeImportedCss`, `cache.enabled`, `cache.devCheckInterval`.
* **Cascade** — Submodule settings now cascade in two tiers: behavioral keys (`driver`, `devMode`, `devServerUrl`, `renderModulePreload`, `includeImportedCss`, `cache`) inherit from the root app, but module-relative paths (`manifestPath`, `buildPath`, `hotFilePath`, `prependPath`, `prependModuleRoot`) fall back to system defaults — they are never silently joined onto a submodule's moduleRoot. Submodules that need a specific path must declare it themselves.
* **Performance** — Drivers and module-bound scopes are cached per module on the singleton service; per-request work is a struct lookup plus a delegate call. Hot-file polling is throttled by `cache.devCheckInterval`.
* **Compat** — The legacy `mixr( asset )` and `mixr( asset, moduleName )` string forms are unchanged. Existing 2.x apps work without configuration changes (the default `auto` driver resolves to the manifest driver in their case).
* **Engines** — Verified on Lucee 5.4.8.2, Lucee 6.2.6.19, Adobe ColdFusion 2018, 2021, and 2023 (40/40 specs).
* **Internals** — `Mixr.cfc` no longer extends `coldbox.system.FrameworkSupertype`; submodule settings are looked up via the `coldbox:moduleSettings:<name>` WireBox DSL.
* **Engines** — Verified on Lucee 5, Lucee 6, Adobe ColdFusion 2023, and BoxLang 1.14. (Adobe ColdFusion 2018 and 2021 are no longer supported.)

## [2.0.1] => 2026-05-07

* **License** - Added license file to the project

## [2.0.0] => 2024-05-21

* **Breaking Change** - Updated default configuration to emulate Laravel Mix 6

## [1.0.0] => 2023-03-07

* First release
