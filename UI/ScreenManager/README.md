# UIScreenManager

`UIScreenManager` provides stack-based navigation for UI screens with optional transition support.

## Setup

1. Add `res://UI/ScreenManager/UIScreenManager.gd` to a UI root (e.g., HUD or menu scene).
2. Register screens via `register_screen(id: StringName, scene: PackedScene)`.
3. Optionally assign `transition_player_path` and `transition_library` (shared with `SceneFlow`).
4. Register reusable templates with `register_template(id, scene)` and push them using `push_template` with a content dictionary.
5. Autoloads required:
   - `ThemeService` (for themed controls)
   - `ThemeLocalization` (for localization helpers when screens rely on tokens)

## API

- `push_screen(id, context)`
- `push_template(template_ref, content, context)`
- `replace_screen(id, context)`
- `pop_screen()`
- `clear_screens()`
- Signals: `screen_pushed`, `screen_replaced`, `screen_popped`, `screen_stack_changed`, `transition_finished`

Context dictionaries are duplicated and passed to screen scripts via `receive_context(context)` and lifecycle callbacks `on_screen_entered`, `on_screen_exited` if implemented.

## EventBus Integration

When `EventBus` autoload is present, the manager publishes:

- `EventTopics.UI_SCREEN_PUSHED`
- `EventTopics.UI_SCREEN_POPPED`

Payloads include `id`, `timestamp_ms`, and `stack_size`.
