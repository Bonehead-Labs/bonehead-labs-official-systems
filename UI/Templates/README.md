# UI Templates

Templates provide Godot scenes pre-wired with the widget library, theme services, and EventBus publishing. They are authored visually and accept content dictionaries at runtime through `apply_content`. Each template extends `UITemplate.gd`, which exposes common helpers for localisation, theme refresh, and event routing.

## Getting Started

1. Instance a template scene, e.g. `res://UI/Templates/DialogTemplate.tscn`.
2. Optionally set `template_id` for analytics and EventBus payloads.
3. Call `apply_content(data_dictionary)` to populate the layout.
4. Connect to `template_event(event_id, payload)` to respond to interactions.

Example: open `res://Example_Scenes/UI/TemplateShowcase.tscn` to see `DialogTemplate` populated at runtime and emitting events.

All templates rely on the existing autoloads:

- `ThemeService` for colours, spacing, and high-contrast settings.
- `ThemeLocalization` for token-based strings.
- `EventBus` for publishing user interactions (`EventTopics.UI_TEMPLATE_EVENT`).

The helper `UITemplateDataBinder` (`DataBinder.gd`) provides typed functions for binding text, textures, slider ranges, and list content.

## Available Templates

### DialogTemplate
- Modal dialog with header, body, and action bar.
- `content` keys: `title`, `description`, `content` (array of entries), `actions` (array of button descriptors).
- Action entries emit `template_event` with `id`/`payload`, and optionally publish a specific EventBus topic.

### SettingsTemplate
- Scrollable settings layout with section headers and widget-based controls.
- Supports control types: `toggle`, `slider`, `button`, `label`, or `scene` (custom PackedScene path).
- Emits events for slider/toggle/button interactions, surfacing current values.

### InventoryTemplate
- Grid container for inventory slots.
- Slots accept `icon`, `label`, `quantity`, `payload`, `event`, and `tooltip` fields.
- Emits an event when the slot button is pressed, providing slot id in the payload.

### ListTemplate
- Vertical list menu with themed buttons.
- Item descriptors define `text`, `tooltip`, `icon`, and `payload`.

### HUDOverlay
- Non-interactive overlay surface for objectives, status text, timed notifications, and progress bars.
- Content keys: `objective`, `status`, `notifications` (array), `bars` (array with `label`, `value`, `max`).

### LoadingScreenTemplate
- Simple loading view with title, subtitle, tip, and progress bar.
- Call `set_progress(value, max)` for incremental updates or `apply_content` for batch configuration.

## Data Binding Helpers

`DataBinder.gd` exposes the `UITemplateDataBinder` class with helpers:

- `apply_text(label, descriptor, resolver)` – handles strings, numbers, or token dictionaries.
- `apply_rich_text(label, descriptor, resolver)` – same as above for `RichTextLabel`.
- `apply_toggle_state(check_button, bool)` – toggles or check buttons.
- `apply_slider_value(range, {min, max, step, value})` – range widgets.
- `apply_texture(texture_rect, descriptor)` – `Texture2D` or resource path.
- `apply_progress(progress_bar, {value, max, text})` – progress bars with tooltip support.
- `populate_container(container, array, callable)` – clears and rebuilds child nodes via factory callback.

The `resolver` callable is usually `UITemplate.resolve_text`, enabling localisation through `ThemeLocalization` tokens.

## EventBus Integration

`UITemplate.emit_template_event(event_id, payload)` signals listeners and publishes to `EventTopics.UI_TEMPLATE_EVENT` with the payload:

```
{
    "template_id": StringName,
    "event_id": StringName,
    "payload": Dictionary
}
```

Subscribe via `EventBus.sub(EventTopics.UI_TEMPLATE_EVENT, callable)` to observe template interactions globally.

## Migration Notes

- `UI/Layouts/MenuBuilder.gd` is now deprecated. Use `SettingsTemplate.tscn`, `DialogTemplate.tscn`, or other templates instead of schema-driven runtime construction.
- Existing menu schemas can be converted by translating sections to `SettingsTemplate` descriptors and action lists to `DialogTemplate` actions.
- `UIScreenManager` exposes `push_template(scene_path, content, options)` replacing `push_menu`.

## Testing

GUT tests cover template data binding and `UIScreenManager` template integration under `UI/UnitTests`. Execute with:

```
godot --headless --run res://addons/gut/gut_cmdln.gd -gselect=test_templates.gd
```

Ensure `ThemeService`, `ThemeLocalization`, and `EventBus` autoloads are present when running templates in isolation.
