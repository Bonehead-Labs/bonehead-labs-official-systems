# AGENTS.md
**Guidelines for Automated Agents Contributing to `bonehead-labs-official-systems`**

This document defines the rules and expectations for AI agents and automated tools that generate or modify code within this repository. The goal is consistent quality, reusability, and developer-friendly structure across all systems.

---

## Core Principles

1. **Godot 4 Syntax Compliance**
   - Target **Godot 4.5**.
   - Do not use pre–Godot-4 patterns or deprecated APIs.

2. **Developer Experience First**
   - Put **public, usable functions** at the top of each script.
   - Put **helpers/private functions** below.
   - Keep files short and scannable.

3. **Modularity & Portability**
   - Each module is **plug-and-play** with **minimal configuration**.
   - Avoid project-specific assumptions and hard-coded paths.
   - Coupled systems must still be separable.

4. **Singletons & Naming**
   - Autoload script filenames are **pure** (e.g., `AudioService.gd`).
   - Inside autoloads, either **omit** `class_name` or **prefix** with `_` (e.g., `class_name _AudioService`).
   - Other scripts reference the autoload name `AudioService`, not the internal class.

   Example:

       # File: AudioService.gd
       class_name _AudioService
       # elsewhere
       AudioService.play("explosion")

5. **Strong Typing**
   - Explicitly type variables, params, and return values.

6. **Documentation & Readability**
   - Public APIs: docstrings with purpose, params, returns, signals.
   - Complex logic: short, actionable comments (focus on “why”).

7. **Prefer Native Godot Tools**
   - Use scenes, nodes, resources, signals, and built-ins where appropriate.
   - Only roll custom code when it clearly improves portability or performance.

8. **Testing with GUT**
   - Every module must include **GUT** unit tests covering:
     - Core happy paths
     - Edge cases and error handling
     - Public API contracts
   - Agents write the tests; the lead developer runs and validates them.

---

## Godot Engine–Specific Considerations & Safeguards

> Agents must follow these rules when making engine-level or scene-level changes.

### Autoloads
- ✅ Preferred: Provide a tiny **setup script** (EditorPlugin tool or CLI doc) that **adds/removes autoloads** via `ProjectSettings` API.
- ✅ Provide **idempotent** registration functions (no duplicates; safe re-run).
- ❌ Do **not** hand-edit `project.godot` lines directly.

### Input Map (Actions & Glyphs)
- ✅ Use `InputMap.add_action()` and `InputMap.action_add_event()` in a **migration/setup script** that is idempotent.
- ✅ Keep a source-of-truth JSON/Resource for actions; generate from it.
- ❌ Do not assume existing actions or overwrite user bindings without a feature flag.

### Physics Layers & Groups
- ✅ Provide a central **PhysicsLayers.gd** (or JSON/Resource) and a setup script that sets labels safely.
- ❌ Do not blindly rewrite layer names; check existing labels before changes.

### Scenes & Node Paths
- ✅ Use **exported NodePaths** or **signal wiring in `_ready()`** to avoid brittle absolute paths.
- ✅ Prefer **composition** (child scenes) and **named marker nodes** for lookups.
- ❌ Do not hardcode deep node paths that break if a scene reorganizes.

### Resources & UIDs
- ✅ Reference resources by **relative path** within the module; avoid absolute paths.
- ✅ Keep `.tres/.res` under the module folder to preserve portability.
- ❌ Do not regenerate resource UIDs or re-serialize resources unnecessarily.

### Import Metadata (e.g., textures, audio)
- ✅ Do not modify `.import` files directly.
- ✅ If import settings are essential, document them or provide a one-off **import preset script**.
- ❌ Do not reorder GUIDs or touch importer cache.

### Editor Plugins / Tool Scripts
- ✅ If needed, write **opt-in** EditorPlugins (`addons/`) with clear namespacing (`bonehead_*`).
- ✅ Ensure **clean uninstall** (remove autoloads, settings, signals).
- ❌ Do not enable tool scripts by default if not required at runtime.

### Project Settings
- ✅ If a setting is required, set it via a **guarded migration** (`if not already set`), and **document** why.
- ❌ Do not mass-edit unrelated settings.

### Export Presets / Platforms
- ✅ Provide **template presets** under `docs/` and instructions; do not auto-edit `export_presets.cfg`.
- ❌ Do not assume target platforms or flip platform flags.

### File/Folder Structure & Merging
- ✅ Keep scene and script changes **small and isolated** to reduce merge conflicts.
- ✅ Avoid sweeping reformatting (e.g., rewrapping .tscn).
- ❌ Do not rename top-level folders without a migration path.

### Deterministic Tests
- ✅ GUT tests must avoid random timers and race-prone async unless necessary; if used, add **timeouts** and **await** robustly.
- ✅ Prefer headless-compatible tests; gate editor-only tests with `Engine.is_editor_hint()`.

---

## General Style

- **Consistency** across modules
- **Minimal configuration** to adopt
- **No hard-coded absolute paths**
- **Clear separation** between runtime systems and editor-time helpers

---

## Conformance

All AI-generated PRs must:
- Include/Update tests (GUT).
- Pass linting and type checks.
- Avoid risky direct edits to project files; use guarded setup/migrations.
