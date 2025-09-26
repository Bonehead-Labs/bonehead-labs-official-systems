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
   - **Godot Documentation Standards**: All documentation MUST follow official GDScript documentation conventions
   - **BBCode Formatting**: Use proper BBCode tags for parameters, returns, and cross-references
   - **Public APIs**: Comprehensive docstrings with purpose, parameters, returns, signals, and usage examples
   - **Complex logic**: Short, actionable comments focusing on "why" not "what"
   - **Consistency**: All modules must use identical documentation patterns

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

## Type Safety & Naming Conflicts

### Variant Inference Prevention
- ❌ **Never** rely on automatic Variant type inference
- ✅ **Always** explicitly type variables, especially when:
  - Values come from `Dictionary.get()`, `metadata.get()`, or similar Variant-returning methods
  - Values are assigned from function calls that return `Variant`
  - Variables are initialized from empty collections `{}`, `[]`
- ✅ Use explicit type annotations: `var transition_name: String = metadata.get("transition", "")`

### Global Identifier Conflicts
- ❌ **Never** name constants the same as existing global classes
- ✅ **Always** append "Script" suffix to preload constants that reference global classes:
  ```gdscript
  # ❌ BAD - shadows FlowAsyncLoader global class
  const FlowAsyncLoader = preload("res://SceneFlow/AsyncSceneLoader.gd")

  # ✅ GOOD - avoids global shadowing
  const AsyncSceneLoaderScript = preload("res://SceneFlow/AsyncSceneLoader.gd")
  ```

### Parameter Shadowing Prevention
- ❌ **Never** use constructor parameters with same names as member variables
- ✅ **Always** prefix constructor parameters with underscores:
  ```gdscript
  # ❌ BAD - shadows member variable
  func _init(scene_path: String, metadata: Dictionary = {}) -> void:
      self.scene_path = scene_path  # shadows self.scene_path

  # ✅ GOOD - avoids shadowing
  func _init(_scene_path: String, _metadata: Dictionary = {}) -> void:
      self.scene_path = _scene_path
  ```

### Godot 4 API Compatibility
- ❌ **Never** assume Godot 4 has all Godot 3 APIs
- ✅ **Always** verify API existence before use:
  - `ResourceLoader.load_threaded_cancel()` ❌ DOES NOT EXIST in Godot 4
  - Implement custom cancellation logic instead
- ✅ Check official Godot 4 documentation for API changes

### GDScript Syntax vs Python
- ❌ **Never** use Python-like syntax in GDScript
- ✅ **Always** use proper GDScript syntax:
  ```gdscript
  # ❌ BAD - Python syntax
  for i in range(size)[::-1]:

  # ✅ GOOD - GDScript syntax
  for i in range(size - 1, -1, -1):
  ```

### Collection Type Limitations
- ❌ **Never** use nested typed collections
- ✅ **Always** use simple Dictionary/Array types for complex data:
  ```gdscript
  # ❌ BAD - not supported
  var glyphs: Dictionary[StringName, Dictionary[StringName, Texture2D]] = {}

  # ✅ GOOD - use untyped Dictionary
  var glyphs: Dictionary = {}
  ```

### GUT Test Method Names
- ❌ **Never** use non-existent test assertion methods
- ✅ **Always** use correct GUT assertion methods:
  - `assert_ne()` ✅ (not equal)
  - `assert_neq()` ❌ DOES NOT EXIST

## General Style

- **Consistency** across modules
- **Minimal configuration** to adopt
- **No hard-coded absolute paths**
- **Clear separation** between runtime systems and editor-time helpers

---

## Documentation Standards Enforcement

> **CRITICAL**: All AI agents must strictly follow these documentation patterns. Non-compliant documentation will be rejected.

### Required Documentation Format

#### Function Documentation Structure
```gdscript
## Brief description of what the function does
## 
## Optional longer description explaining purpose, behavior, or important details
## 
## [b]param_name:[/b] Description of the parameter
## [b]param_name:[/b] Description of the parameter
## 
## [b]Returns:[/b] Description of what the function returns
## 
## [b]Usage:[/b]
## [codeblock]
## # Example usage code
## var result = function_name(param1, param2)
## [/codeblock]
```

#### Signal Documentation Structure
```gdscript
## Emitted when [event description]
## 
## [b]param_name:[/b] Description of the signal parameter
## [b]param_name:[/b] Description of the signal parameter
signal signal_name(param_name: Type, param_name: Type)
```

#### Member Variable Documentation
```gdscript
## Brief description of the variable's purpose
## 
## [b]Default:[/b] Default value or behavior
var member_name: Type = default_value
```

### BBCode Tags Reference

#### Required Tags
- `[b]parameter:[/b]` - For function parameters
- `[b]Returns:[/b]` - For return value descriptions
- `[b]Default:[/b] - For default values
- `[b]Usage:[/b]` - For code examples

#### Cross-Reference Tags
- `[method function_name]` - Link to another method
- `[signal signal_name]` - Link to a signal
- `[member variable_name]` - Link to a member variable
- `[enum EnumName]` - Link to an enum
- `[constant CONSTANT_NAME]` - Link to a constant

#### Formatting Tags
- `[codeblock]` - For multi-line code examples
- `[br]` - Line breaks within descriptions
- `[i]text[/i]` - Italic text for emphasis
- `[b]text[/b]` - Bold text for emphasis

### Forbidden Patterns

#### ❌ NEVER Use These
```gdscript
# ❌ BAD - Non-standard parameter format
## Args:
##   param: description
##   param: description

# ❌ BAD - Non-standard return format  
## @param param description
## @return return description

# ❌ BAD - Inconsistent formatting
## Parameters:
## - param: description
## - param: description
```

#### ✅ ALWAYS Use These
```gdscript
# ✅ GOOD - Standard BBCode format
## [b]param:[/b] description
## [b]param:[/b] description
## 
## [b]Returns:[/b] description
```

### Documentation Coverage Requirements

#### Public Functions (Required)
- **Purpose**: What the function does
- **Parameters**: All parameters with types and descriptions
- **Returns**: Return type and description
- **Usage**: Code example showing typical usage
- **Cross-references**: Links to related methods/signals when relevant

#### Signals (Required)
- **When emitted**: Clear description of trigger conditions
- **Parameters**: All signal parameters with types and descriptions
- **Usage**: Example of how to connect and use the signal

#### Member Variables (Required for public/exported)
- **Purpose**: What the variable represents
- **Default**: Default value and behavior
- **Usage**: When and how to modify the variable

#### Private/Internal Functions (Optional but Recommended)
- **Purpose**: Brief description for complex logic
- **Why**: Focus on "why" this approach was chosen

### Validation Checklist

Before submitting any code changes, verify:

- [ ] All public functions have complete documentation
- [ ] All signals have parameter documentation
- [ ] All exported variables have documentation
- [ ] No `@param` or `@return` tags exist
- [ ] No `## Args:` or `## Options:` patterns exist
- [ ] All parameters use `[b]param:[/b]` format
- [ ] All returns use `[b]Returns:[/b]` format
- [ ] Cross-references use proper BBCode tags
- [ ] Code examples are wrapped in `[codeblock]`
- [ ] Documentation is consistent across the entire module

### Examples of Correct Documentation

#### Function with Parameters and Returns
```gdscript
## Play a sound effect with optional volume and pitch adjustment
## 
## Plays a registered sound effect with the specified options. The sound
## will be routed to the appropriate audio bus based on the sound's
## registration settings.
## 
## [b]sound_id:[/b] The registered sound identifier
## [b]options:[/b] Dictionary containing:
## - [b]vol_db:[/b] Volume adjustment in decibels (default 0.0)
## - [b]pitch:[/b] Pitch multiplier (default 1.0)
## - [b]pos:[/b] 2D position for spatial audio
## 
## [b]Returns:[/b] The AudioStreamPlayer2D instance or null if sound not found
## 
## [b]Usage:[/b]
## [codeblock]
## # Play explosion sound at half volume
## var player = AudioService.play_sfx("explosion", {"vol_db": -6.0})
## 
## # Play UI click with custom pitch
## AudioService.play_sfx("click", {"pitch": 1.2})
## [/codeblock]
func play_sfx(sound_id: StringName, options: Dictionary = {}) -> AudioStreamPlayer2D:
```

#### Signal Documentation
```gdscript
## Emitted when a sound effect is played
## 
## [b]sound_id:[/b] The identifier of the sound that was played
## [b]audio_type:[/b] The type of audio ("2D", "3D", or "UI")
signal sfx_played(sound_id: StringName, audio_type: String)
```

#### Member Variable Documentation
```gdscript
## Crossfade duration for music transitions
## 
## [b]Default:[/b] 2.0 seconds
## 
## Controls how long music tracks take to fade between each other.
## Set to 0.0 for instant transitions.
@export var music_crossfade_seconds: float = 2.0
```

### Quick Reference

#### Essential Patterns
```gdscript
## [b]param:[/b] description
## [b]Returns:[/b] description
## [b]Usage:[/b]
## [codeblock]
## # example code
## [/codeblock]
```

#### Common Cross-References
```gdscript
## See [method function_name] for related functionality
## Emits [signal signal_name] when complete
## Uses [member variable_name] for configuration
```

### Enforcement Actions

1. **Pre-commit Validation**: All documentation must pass format validation
2. **Code Review**: Documentation compliance is mandatory for approval
3. **Automated Checks**: Linting tools will flag non-compliant patterns
4. **Rejection Policy**: PRs with non-compliant documentation will be rejected

---

## Conformance

All AI-generated PRs must:
- Include/Update tests (GUT).
- Pass linting and type checks.
- **Follow documentation standards** (BBCode format, complete coverage).
- Avoid risky direct edits to project files; use guarded setup/migrations.
