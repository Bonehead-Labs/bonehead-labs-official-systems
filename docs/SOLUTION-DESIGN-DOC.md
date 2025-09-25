# SOLUTION_DESIGN.md
**AI-Friendly Solution Design for `bonehead-labs-official-systems`**

This document outlines existing systems and planned modules with integration points, constraints, and engine-specific safeguards. AI agents must adhere to this design when implementing features.

---

## Existing Systems (v0.1)

### EventBus
- `EventTopics.gd` registry
- Autoload singleton
- Centralized pub/sub for inter-system communication

### SaveService
- Autoload singleton
- Profiles & persistence
- **Single source of truth for serialization**
- Other systems expose **save/load hooks** only

### InputService
- Autoload singleton
- Input mapping & rebind manager
- Integrates with Player Controller and interactables

### AudioService
- Autoload singleton
- SFX/music playback utilities and grouped channels

---

## New Systems

### Scene Flow
- `FlowManager` (Autoload)
- Scene Stack (push/pop)
- Async Loader + Loading Screen
- **Shared Transition FX** (uses UI Transition Library)
- Payload Passing between scenes
- Error handling hooks
- Invokes **World.CheckpointManager** (does not own checkpoints)
- GUT unit-test stubs

### UI System
- Theme & Style Tokens
- Widget Library (Button, Toggle, Slider, core Controls)
- Screen Manager (Title, Pause, Options, Save/Load, Credits)
- HUD Shell (in-game overlays)
- Input Glyph Support (dynamic per device)
- **Transition/Animation Library (shared with Scene Flow)**

### Player Controller (2D)
- Controller core with **MovementConfig** (Resource/JSON)
- **Generic FSM** (shared framework) for player states
- Animation driver (AnimationPlayer & AnimatedSprite2D)
- Camera Rig 2D (configurable feel)
- Interaction Detector
- Ability Shell (pluggable abilities)
- Damage/Knockback **hooks to Combat**
- Player signals (spawn, death, hit, interact, etc.)

### Combat System
- Health component
- DamageInfo Resource
- Hitbox/Hurtbox components
- Knockback & Stagger
- Status Effects (DoT, buffs/debuffs, speed, etc.)
- Death handler
- Projectiles framework
- Faction/Team Manager (player vs NPCs)

### Enemy AI (2D)
- Enemy Base class
- **Generic FSM** (shared)
- Perception (Area2D-based)
- Navigation2D integration
- Pluggable Attack Modules
- Steering helpers
- Loot/Death hooks
- Spawner + Wave Manager

### Items & Economy
- `ItemDef` Resource or JSON
- `LootTable` Resource or JSON
- InventoryLite component
- CurrencyWallet component
- Pickup & Drop nodes
- Shop System
- Crafting & Upgrade module
- Equipment slots
- **Serialization hooks delegate to SaveService**

### World
- **Checkpoint Manager** (single owner)
- Interactable interface + base nodes (Door, Lever, Chest, Button)
- Level Loader / Portal system
- Hazard Volume (damage zones)
- Destructible environment framework
- World TimeManager (optional/stub)
- Physics & Layers definitions
- **Serialization hooks delegate to SaveService**

### Debug & QA Tools
- Performance overlay
- Debug console
- Cheat / QA menu
- UI outline mode
- EventBus tap/inspector
- Log window
- Scene tester
- Crash reporter (optional)
- Config / Access control (optional)

---

## Cross-Cutting Architecture Decisions

- **Autoloads**: `EventBus`, `SaveService`, `InputService`, `AudioService`, `FlowManager`.
- **FSM**: A reusable FSM framework shared by Player and Enemies; state config decoupled from logic where possible.
- **Transitions**: One **shared** transition/animation library for UI and Scene Flow.
- **Serialization**: Only `SaveService` persists data; other systems raise events or provide snapshot structs/resources.
- **Signals**: Prefer signals for decoupling; avoid tight node path coupling.
- **Resources**: Use typed Resources for configs (movement, damage, items, loot).

---

## Godot Engine–Specific Considerations & Safeguards

### Autoload Registration
- Provide a **setup/migration script** (idempotent) that registers autoloads via `ProjectSettings`.
- Do **not** hand-edit `project.godot`.
- Example (pseudo):

       static func ensure_autoload(name: String, path: String) -> void:
           var list := ProjectSettings.get_setting("autoload") as Dictionary
           if not list.has(name):
               ProjectSettings.set_setting("autoload/"+name, {"path": path, "singleton": true})
               ProjectSettings.save()

### Input Map & Glyphs
- Maintain a **single JSON/Resource** for actions.
- Provide an **idempotent loader** that creates/updates actions via `InputMap`.
- Never delete or overwrite user binds silently; add new actions conservatively.

### Physics Layers & Groups
- Keep a **central definition** and guarded setter (only set labels if empty or matching known defaults).
- Avoid renaming existing labels without explicit migration.

### Scenes & Node Paths
- Use **exported NodePaths** and **marker nodes**. Resolve in `_ready()` with guarded checks.
- Don’t rely on deep absolute paths; prefer composition and interfaces.

### Resources & Imports
- Keep module resources relative to the module directory.
- Do not touch `.import` files; document required import settings instead.

### Editor Plugins
- Place optional editor tools in `addons/bonehead_*`.
- Ensure clean enable/disable and uninstallation.

### Project Settings & Export
- Document required settings; change them via **guarded** migrations only.
- Provide sample export presets in `docs/` rather than mutating `export_presets.cfg`.

### Testing (GUT)
- Tests should run headless reliably.
- For async/await, use timeouts and deterministic signals.
- Avoid test flakiness (timing-only assertions; race conditions).

---

## Deliverables & Checklists for AI Agents

- **Code** with strong typing, docstrings, and top-loaded public APIs.
- **GUT tests** for each module (happy path + edge cases).
- **Setup/migration scripts** for:
  - Autoloads
  - InputMap actions
  - Physics layer labels (guarded)
- **Docs**:
  - Quick start for the module
  - Integration points (EventBus topics, Save hooks)
  - Known limitations

**PR must not**:
- Blindly edit `project.godot`, `.tscn` structure, `.import` files, or export presets.
- Introduce brittle node paths or hidden editor dependencies.

---

## Example Integration Flow (High Level)

1. Install module folder under `addons/bonehead_*` or `systems/*`.
2. Run provided **setup script** (or follow manual steps) to:
   - Register autoloads
   - Ensure input actions
   - Label physics layers (if needed)
3. Add system scenes/resources as children or via composition.
4. Wire signals / interfaces (avoid hard paths).
5. Run **GUT** tests and verify.
