# UI Enhancement Roadmap

## Milestone 1 – Foundations & Dependency Checks
- [x] Update `UI/README.md` (and module-level docs) to clearly list required autoload singletons and manual setup steps, mirroring the tone/structure of AudioService documentation.
- [x] Add guard clauses/conditional checks inside widgets and utilities to raise descriptive errors when required autoloads (e.g., `ThemeService`, `ThemeLocalization`, `EventBus`) are missing, following the EventBus demo pattern.
- [x] Extend `WidgetFactory` to expose container helpers (`create_panel`, `create_vbox`, `create_hbox`) that respect AGENTS naming/type rules and surface missing dependencies gracefully.
- [x] Add GUT coverage that instantiates each factory helper, verifies theme/localization bindings, and validates error messaging when dependencies are absent.
- [x] Ensure all public APIs created in this milestone include BBCode-compliant docstrings detailing dependency expectations.

## Milestone 2 – Composable Layout Shells
- [x] Introduce reusable scene templates under `UI/Layouts/` (e.g., `PanelShell.tscn`, `DialogShell.tscn`, `ScrollableLogShell.tscn`) with exported slots instead of hard-coded node paths.
- [x] Author matching builder scripts (`PanelShell.gd`, etc.) exposing typed configuration methods to inject header/body/footer content, while performing autoload dependency checks on `_ready()`.
- [x] Update docs with usage examples demonstrating shell composition via exported NodePaths and WidgetFactory helpers.
- [x] Add integration tests that load each shell scene in headless mode, confirming slot wiring and theme updates respond to simulated `ThemeService.theme_changed` signals.
- [x] Provide migration notes showing how existing demos (EventBusDemo) can replace bespoke panels without manual layout code (no code changes yet).

## Milestone 3 – Data-Driven Menu Composition
- [ ] Define a config schema (`UI/Layouts/menu_schema.example.tres` or `.gd`) for describing sections, controls, and actions; ensure schema avoids nested typed collections per AGENTS guidance.
- [ ] Implement a `MenuBuilder.gd` utility that consumes the schema, instantiates shells + widgets via the factory, and wires signals using exported callbacks, while checking for required autoloads and logging descriptive errors when missing.
- [ ] Include validation helpers that surface misconfigured tokens/actions through descriptive errors instead of asserts.
- [ ] Document the schema (docs + in-file docstrings) using Godot BBCode conventions with sample JSON/GDScript dictionaries.
- [ ] Cover `MenuBuilder` with GUT tests for happy paths, missing tokens, and duplicate actions.

## Milestone 4 – Integration & Showcase
- [ ] Wire `UIScreenManager` to accept config-driven menus (e.g., `push_menu(config_dict)`) while preserving existing APIs and validating autoload availability before use.
- [ ] Build an `Example_Scenes/UI/ConfigMenuDemo` scene proving end-to-end setup (Theme services, MenuBuilder, ScreenManager, EventBus interactions).
- [ ] Provide CI-friendly scripts or docs ensuring demos can run headless (`Engine.is_editor_hint()` guards for visual components).
- [ ] Add final documentation updates: roadmap, FAQ, and references to automation scripts; mirror tone/structure of solid modules like AudioService/EventBus.
- [ ] Ensure all new public APIs ship with GUT coverage and docstrings; include verification checklist before closeout.

## Ongoing Quality Gates
- Mirror AGENTS.md: keep new autoload references prefixed with `_` internally, type every variable, and avoid touching `.import` or unrelated settings.
- For every milestone, prepare Conventional Commit scopes, and require tests/docs before landing.
- Reassess widgets for accessibility (focus outlines, localization fallbacks) whenever themes change; include TODOs if follow-up work is necessary.
