# Milestone Roadmap

> Generated under the guidelines from `AGENTS.md` and `SOLUTION-DESIGN-DOC.md`. Each checklist item maps to a required Conventional Commit. After all TODOs for a milestone are complete, author GUT coverage and land a final milestone commit that contains only the tests and related fixtures. Ensure headless lint/type checks succeed before every commit.

## Scene Flow System

### Milestone 1: FlowManager Core Autoload
- [x] Implement `FlowManager.gd` autoload with typed public API (`push_scene`, `pop_scene`, `replace_scene`, `peek_scene`, `clear_stack`).
- [x] Persist stack entries with payload metadata structs to allow scene-to-scene data passing.
- [x] Emit typed signals for transition lifecycle (`about_to_change`, `scene_changed`, `scene_error`).
- [x] Publish opt-in analytics diagnostics via `EventBus` topics for stack operations.
- [x] Provide developer README covering usage patterns and EventBus topics.
- [x] Supply idempotent setup script to register the autoload via `ProjectSettings`.

### Milestone 2: Async Loading & Loading Screen Hooks
- [x] Add asynchronous loader utility with progress reporting, cancellation guard, and deterministic replay hooks (consuming `RNGService` seeds when required).
- [x] Define loading screen contract (interface or abstract scene) and expose FlowManager configuration to register it.
- [x] Integrate loading progress callbacks for UI system consumption.
- [x] Emit loading diagnostics/analytics as opt-in `EventBus` events.
- [x] Implement error fallback behaviour and emit diagnostics via EventBus.

### Milestone 3: Shared Transition FX Integration
- [x] Create reusable transition resource/library with enter/exit sequences (leveraging cross-cutting transition module once delivered).
- [x] Wire FlowManager to trigger transition FX around stack mutations with configurable defaults.
- [x] Publish transition completion signals for UI subscribers and analytics hooks.
- [x] Document extension hooks for custom transitions.

### Milestone 4: World & Save Hooks
- [x] Invoke `World.CheckpointManager` checkpoint updates during scene swap events when available.
- [x] Provide opt-in hooks for `SaveService` snapshot requests via `SettingsService` for persistent preferences prior to scene unload.
- [x] Add guard rails for editor-only execution (`Engine.is_editor_hint`).
- [x] Update docs with integration guidance for world/save systems and analytics instrumentation.

## UI System

### Milestone 1: Theme, Tokens, and Accessibility Shell
- [x] Define theme resource with typography, color, spacing, and high-contrast tokens stored under `UI/Theme`.
- [x] Register focus outline/focus highlight assets and expose accessibility toggles.
- [x] Implement localization token access helper hooking into `TranslationServer` with fallback strategies.
- [x] Document theming, localization workflow, and accessibility expectations.
- [x] Provide setup script (if needed) to register theme resources without touching project settings directly.

### Milestone 2: Core Widget Library
- [ ] Build base button, toggle, slider, and label controls using the shared theme and accessibility defaults (focus outlines, high-contrast mode).
- [ ] Expose public factory methods for widget instancing with localization-aware text setters.
- [ ] Add accessibility hooks (focus, state signals) and docstrings.
- [ ] Supply per-widget README with usage snippets and analytics opt-in guidance.

### Milestone 3: Screen Manager & Navigation
- [ ] Create `UIScreenManager` responsible for title/pause/options/etc. with scene composition.
- [ ] Implement stack-based navigation with animated show/hide powered by transition library.
- [ ] Expose signals for screen opened/closed and integrate with EventBus topics, including analytics events.
- [ ] Document how to register new screens and wire InputService actions and localization keys.

### Milestone 4: HUD Shell & Input Glyphs
- [ ] Provide HUD root scene with pluggable panels (health, inventory prompts, quest log stubs).
- [ ] Integrate InputService glyph provider for dynamic device icons.
- [ ] Add extensibility API for gameplay systems to register HUD widgets with localization/accessibility metadata.
- [ ] Update documentation with glyph usage, HUD composition patterns, and analytics hooks.

### Milestone 5: Input Rebind UI
- [ ] Implement Input Rebind UI scenes leveraging `InputService` rebind APIs and localization tokens.
- [ ] Provide deterministic state persistence via `SettingsService` so rebinds survive restarts.
- [ ] Emit analytics events for rebind success/failure (opt-in) through EventBus.
- [ ] Document flow for integrating the rebind UI into `UIScreenManager`.

## Player Controller (2D)

### Milestone 1: Movement Core & Config
- [ ] Create `MovementConfig` Resource defining speed, acceleration, jump, damping, etc.
- [ ] Implement player controller script with typed export of config and basic locomotion.
- [ ] Emit movement-related signals (spawn, landed, jump) for other systems and analytics.
- [ ] Provide README outlining config tuning workflow and deterministic seeding considerations with `RNGService`.

### Milestone 2: Generic FSM Framework
- [ ] Author shared FSM module (states, transitions, context) reusable by enemies.
- [ ] Port player controller logic to FSM states (idle, move, jump, fall).
- [ ] Document state lifecycle and hooks for ability modules.
- [ ] Add minimal tooling to visualize current state via debug overlay integration point.

### Milestone 3: Animation Driver & Camera Rig
- [ ] Wire AnimationPlayer/AnimatedSprite2D to FSM state changes with typed mappings.
- [ ] Build configurable camera rig scene (follow smoothing, lookahead).
- [ ] Expose hooks for cutscenes and FlowManager transitions.
- [ ] Document animation setup requirements and camera attach instructions.

### Milestone 4: Interaction & Ability Shell
- [ ] Implement interactable detector using Area2D and filtered groups.
- [ ] Create ability system interface allowing modular abilities to register with the FSM.
- [ ] Emit interaction signals and integrate with EventBus topics for prompts and analytics.
- [ ] Provide example ability scripts and documentation.

### Milestone 5: Combat Hooks & Save Integration
- [ ] Add damage intake methods forwarding to Combat system via signals.
- [ ] Register save/load snapshot hooks with SaveService for persistent player state, mediated through `SettingsService` when appropriate.
- [ ] Document serialization payload contract and failure handling.

## Combat System

### Milestone 1: Health & Damage Core
- [ ] Implement `HealthComponent` with typed signals and SaveService snapshot integration.
- [ ] Define `DamageInfo` Resource capturing amount, type, source, metadata.
- [ ] Add utility for applying damage with invulnerability windows and error checks.
- [ ] Document core combat API, analytics hooks, and usage patterns.

### Milestone 2: Hitbox/Hurtbox Framework
- [ ] Build components for hitboxes/hurtboxes leveraging Area2D/3D where relevant.
- [ ] Implement collision filtering with faction/team tags.
- [ ] Emit contact events via EventBus for analytics/debug tooling.
- [ ] Provide setup guidance for attaching hitboxes to scenes.

### Milestone 3: Knockback, Stagger, Status Effects
- [ ] Implement knockback resolver applying physics impulses respecting mass.
- [ ] Create status effect manager supporting DoT, buffs, debuffs with timers.
- [ ] Add hooks for movement/ability systems to respond to status changes.
- [ ] Document status effect authoring, stacking rules, and deterministic seed usage when relying on chance.

### Milestone 4: Projectiles, Factions, and Object Pooling
- [ ] Build projectile base scene with pooling support and configurable motion scripts via the shared object pooling utility.
- [ ] Implement faction/team manager singleton with registration API.
- [ ] Integrate projectiles with damage pipeline including friendly-fire rules.
- [ ] Document extending projectile behaviours and faction setup with pooling considerations.

### Milestone 5: Death Handling & Integration
- [ ] Provide death handler callbacks (death animation, loot events).
- [ ] Emit analytics/debug info through EventBus (opt-in).
- [ ] Hook into FlowManager/World for respawn logic where applicable.
- [ ] Document lifecycle expectations for systems consuming combat events.

## Enemy AI (2D)

### Milestone 1: Enemy Base & FSM Integration
- [ ] Develop enemy base class leveraging shared FSM with movement/combat hooks.
- [ ] Provide configuration resource for stats/behaviour parameters.
- [ ] Document required nodes (CollisionShape2D, sensors) and setup.
- [ ] Add signals for spawned, alerted, defeated and analytics emission toggles.

### Milestone 2: Perception & Navigation
- [ ] Implement Area2D-based perception cones and proximity sensors.
- [ ] Integrate Navigation2D pathing with steering helpers.
- [ ] Expose debug visualization toggles via Debug Tools system.
- [ ] Document tuning of detection ranges and path weights, including deterministic RNG handling.

### Milestone 3: Attack Modules & Steering
- [ ] Create pluggable attack behaviours (melee, ranged, special) using Strategy pattern.
- [ ] Provide steering helpers (seek, flee, wander) for smooth movement.
- [ ] Emit attack lifecycle events for Combat system listeners and analytics subscribers.
- [ ] Document module interface so designers can extend behaviours.

### Milestone 4: Spawner & Wave Manager
- [ ] Build enemy spawner nodes with pooling and spawn rules integrated with the shared object pooling utility.
- [ ] Implement wave manager resource to sequence encounters.
- [ ] Hook spawn/clear events into FlowManager or World triggers, with analytics instrumentation.
- [ ] Document integration with level scripts, SaveService persistence, and deterministic seed reuse.

## Items & Economy

### Milestone 1: Item Definitions & InventoryLite
- [ ] Define `ItemDef` Resource schema for stats, rarity, tags.
- [ ] Implement lightweight inventory component with capacity rules and signals.
- [ ] Provide serialization snapshots via SaveService hooks using `SettingsService` helpers for preference storage.
- [ ] Document resource authoring workflow and analytics opt-in points.

### Milestone 2: Loot Tables & Pickup/Drop
- [ ] Create `LootTable` Resource with weighted entries and conditions leveraging `RNGService` for deterministic draws.
- [ ] Implement pickup/drop nodes referencing item defs and auto-collect rules.
- [ ] Emit pickup/drop events over EventBus for analytics/HUD updates.
- [ ] Document hooking loot tables into combat/world events.

### Milestone 3: Currency Wallet & Shop System
- [ ] Implement wallet component supporting multiple currencies with validation.
- [ ] Create shop system scenes for buying/selling leveraging UI widgets and localization tokens.
- [ ] Integrate InputService actions for navigation and confirm/cancel, with analytics logging.
- [ ] Document shop configuration and extensibility points.

### Milestone 4: Crafting, Upgrades, Equipment
- [ ] Build crafting module handling recipes, validation, and outcomes using deterministic RNG hooks when randomization is required.
- [ ] Implement equipment slots system applying stat modifiers to player/enemies.
- [ ] Provide upgrade progression hooks tied to SaveService persistence.
- [ ] Document crafting/equipment APIs with examples and analytics instrumentation guidance.

## World System

### Milestone 1: Checkpoint Manager
- [ ] Implement `CheckpointManager` singleton owning checkpoint data & SaveService integration.
- [ ] Expose APIs for registering checkpoints, activating, and querying current state.
- [ ] Emit checkpoint events for FlowManager/Player systems with optional analytics payloads.
- [ ] Document checkpoint setup and best practices.

### Milestone 2: Interactable Base Nodes
- [ ] Create interactable interface/base class with standard signals.
- [ ] Provide prefab scenes for Door, Lever, Chest, Button using composition.
- [ ] Integrate with Player interaction detector and EventBus, including analytics hooks.
- [ ] Document how to extend base interactable behaviours.

### Milestone 3: Level Loader & Portals
- [ ] Develop level loader helper using FlowManager for scene transitions.
- [ ] Implement portal nodes handling entry/exit conditions and payloads.
- [ ] Provide safeguards against missing destinations, emit diagnostics, and route analytics events.
- [ ] Document level linking workflow and deterministic seed sharing when needed.

### Milestone 4: Hazards & Destructibles
- [ ] Implement hazard volumes dealing periodic or instant damage via Combat system.
- [ ] Provide destructible prop framework with health integration and loot hooks.
- [ ] Emit analytics events for destruction/hazard triggers.
- [ ] Document hooking hazards with checkpoints and respawn logic.

### Milestone 5: Physics Layers & World Time Manager
- [ ] Author central physics layer definition resource and guarded setup script.
- [ ] Implement optional world time manager stub with pause/resume API.
- [ ] Document physics layer expectations for level designers.
- [ ] Outline extension plan for full time-of-day system informed by deterministic RNG requirements.

## Debug & QA Tools

### Milestone 1: Performance Overlay & Log Window
- [ ] Create overlay UI showing FPS, frame time, memory, and custom metrics.
- [ ] Develop log window subscribing to EventBus diagnostics topics.
- [ ] Provide toggles via debug keybinds (using InputService action definitions).
- [ ] Document enabling/disabling overlay in builds.

### Milestone 2: Debug Console, Cheat Menu & Security Gating
- [ ] Implement in-game console with command registry and permission levels.
- [ ] Build cheat/QA menu interfacing with Player/World systems safely.
- [ ] Gate console activation behind secure dev-only flag/environment configuration with audited access logs.
- [ ] Document how to register new commands, secure the interface, and route analytics.

### Milestone 3: EventBus Inspector & Scene Tester
- [ ] Create inspector tool visualizing EventBus topics and payloads.
- [ ] Build scene tester utility for loading scenes with mock services.
- [ ] Ensure tools run in editor and standalone builds guarded by flags.
- [ ] Document usage within QA workflows.

### Milestone 4: Crash Reporter & Config Access
- [ ] Provide optional crash reporter stub hooking into Godot crash signals.
- [ ] Implement configuration access control for enabling debug features.
- [ ] Document integration steps, production safeguards, and analytics opt-in patterns.

## Cross-Cutting Modules

### Milestone 0: Repository & CI Foundation
- [x] Scaffold CI/headless scripts for linting and type checks (`godot --headless --check-only`, formatting, etc.).
- [x] Provide reusable headless GUT test runner script and document CI integration.
- [x] Author contribution guide outlining Conventional Commit usage and local verification steps.
- [x] Supply developer tooling to enforce commit message style (e.g., git hook template) without modifying global config.

### Milestone 1: Autoload & InputMap Setup Utilities
- [ ] Create reusable setup scripts for registering autoloads idempotently.
- [ ] Author input action source-of-truth resource/JSON with loader script using `InputMap` APIs.
- [ ] Document execution steps for these setup helpers.
- [ ] Ensure scripts guard against editor execution and respect existing user bindings.

### Milestone 2: Shared Transition Library (UI + Scene Flow)
- [ ] Finalize shared transition resource definitions consumable by both systems.
- [ ] Provide factory/helpers for common transitions (fade, wipe, slide).
- [ ] Document integration patterns for other modules to adopt transitions.
- [ ] Supply sample scenes demonstrating usage.

### Milestone 3: FSM Toolkit (Player + Enemy)
- [ ] Extract FSM framework into standalone module under `systems/fsm`.
- [ ] Provide base state classes with lifecycle docstrings and typed context.
- [ ] Write integration guide for consuming systems (Player, Enemy, Debug tools).
- [ ] Produce example states/tests verifying core transitions.

### Milestone 4: SaveService Integration Guidelines
- [ ] Create documentation/resources describing save snapshot contracts for all systems.
- [ ] Provide helper utilities for registering saveable components with priority ordering.
- [ ] Define error handling patterns and EventBus notifications for save/load failures.
- [ ] Ensure guidance includes sample unit tests demonstrating snapshot round-trips.

### Milestone 5: SettingsService Autoload
- [ ] Implement `SettingsService` autoload managing user preferences with SaveService hooks and priority registration.
- [ ] Expose typed APIs for storing/retrieving settings (audio, input, accessibility, localization).
- [ ] Provide idempotent setup script to register the autoload.
- [ ] Document integration points for other systems and analytics toggles.

### Milestone 6: RNGService & Deterministic Testing
- [ ] Create `RNGService` autoload with seed control, deterministic sequence APIs, and SaveService snapshot support.
- [ ] Provide helpers for systems/tests to request scoped RNG instances.
- [ ] Document guidelines for deterministic tests and gameplay features.
- [ ] Emit analytics when seeds change (opt-in) for debugging reproducibility.

### Milestone 7: Object Pooling Utility
- [ ] Develop generic pooling utility supporting nodes/resources for projectiles, enemies, FX.
- [ ] Expose typed API for requesting/returning pooled instances with analytics instrumentation.
- [ ] Provide sample integrations for Combat projectiles and Enemy spawners.
- [ ] Document best practices for pooling lifecycles and deterministic resets.

### Milestone 8: Analytics & Diagnostics Layer
- [ ] Define analytics opt-in configuration defaulting to disabled and controlled via `SettingsService`.
- [ ] Provide helper functions for emitting structured analytics payloads over EventBus.
- [ ] Document privacy/scope guidelines and integration steps for other modules.
- [ ] Supply example tests verifying analytics toggles and payload formatting.

---

Each milestone concludes with a dedicated GUT test suite commit validating happy paths, edge cases, and public API contracts, executed after all feature TODO checkboxes above are satisfied.
