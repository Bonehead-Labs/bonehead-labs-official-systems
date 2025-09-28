# UI System

## Required Autoloads

| Autoload Name | Script Path | Purpose |
| --- | --- | --- |
| `ThemeService` | `res://UI/Theme/ThemeService.gd` | Theme tokens, high-contrast toggles |
| `ThemeLocalization` | `res://UI/Theme/LocalizationHelper.gd` | Localization fallbacks for UI tokens |
| `InputService` | `res://InputService/InputService.gd` | Action rebinds, device tracking |
| `InputGlyphService` | `res://UI/HUD/InputGlyphService.gd` | Device-aware action glyphs |
| `SettingsService` (optional) | _custom implementation_ | Persists user preferences (bindings, analytics) |

> ⚠️ **Dependency checks**: The UI module intentionally fails fast when these autoloads are missing. Widgets emit descriptive errors (e.g., `"ThemeService autoload not found"`) during `_ready()`. Add the autoloads before instantiating any UI scenes.

## Theme Tokens & Accessibility

- Default tokens: `res://UI/Theme/default_theme.tokens.tres`
- Helper service: add `res://UI/Theme/ThemeService.gd` as an autoload named `ThemeService`.
- Localization helper: add `res://UI/Theme/LocalizationHelper.gd` as `ThemeLocalization` to translate token strings with fallbacks.
- Toggle high contrast at runtime using `ThemeService.enable_high_contrast(true)`.
- Query colors, spacing, and font sizes from `ThemeService`.
- Retrieve focus outlines via `ThemeService.get_focus_stylebox()` for consistent accessibility visuals.

### Integrating Your Own Theme

1. Duplicate `default_theme.tokens.tres`.
2. Adjust primary/high-contrast palettes, spacing, and typography entries.
3. Call `ThemeService.load_tokens(<path>)` during bootstrapping.

### Accessibility Hooks

- Respect user preferences by toggling `ThemeService.enable_high_contrast`.
- The focus stylebox automatically adapts when high contrast mode changes.
- Consumers can check `ThemeService.is_high_contrast_enabled()` to adjust additional visuals.
- Use `ThemeLocalization.translate(token, fallback)` to fetch UI copy while providing deterministic defaults when translations are missing.

## Widget Library

Reusable controls live under `res://UI/Widgets/`:

- `BaseButton.gd`, `BaseToggle.gd`, `BaseSlider.gd`, `ThemedLabel.gd`
- `WidgetFactory.gd` exposes `create_button`, `create_toggle`, `create_slider`, and `create_label`
- `WidgetFactory.gd` also ships layout helpers (`create_panel`, `create_vbox`, `create_hbox`) so you can compose menus without hand-coding container nodes.

All widgets subscribe to `ThemeService.theme_changed` so they react to palette updates and high-contrast toggles automatically.

## Layout Shells

Reusable shells live under `res://UI/Layouts/` and provide ready-to-wire composition slots:

- `PanelShell.tscn` + `_PanelShell`: panel wrapper exposing `set_header`, `set_body`, `set_footer`, and matching clear/getters.
- `DialogShell.tscn` + `_DialogShell`: dialog surface with title/description labels and action bar helpers (`set_title`, `set_description`, `add_action`).
- `ScrollableLogShell.tscn` + `_ScrollableLogShell`: log surface with `append_entry`/`set_entries` APIs and a capped scrollback.

Example usage:

```gdscript
var panel_scene := load("res://UI/Layouts/PanelShell.tscn")
var panel_shell := panel_scene.instantiate() as _PanelShell
add_child(panel_shell)

var header := WidgetFactory.create_label({"label_fallback": "Event Bus"})
panel_shell.set_header(header)

var content := WidgetFactory.create_vbox({})
content.add_child(WidgetFactory.create_label({"label_fallback": "Waiting for events..."}))
panel_shell.set_body(content)
```

### Migration Notes

- `Example_Scenes/EventBus/EventBusDemo.gd` can swap its hand-built panel for `ScrollableLogShell.tscn` while using `WidgetFactory` buttons/labels. The log shell already exposes `append_entry` and accepts additional header controls via `set_header`.
- Existing UI overlays should add required autoloads, instance the shell scenes, and feed content through the slot APIs rather than creating raw `PanelContainer`/`VBoxContainer` nodes.

### Template System

- `UITemplate.gd` (see `res://UI/Templates/UITemplate.gd`) provides a base class for scene-authored templates that expose `apply_content` and publish `template_event`.
- `Example_Scenes/UI/TemplateShowcase.tscn` instantiates `DialogTemplate` directly, applies content data, and logs template events so you can see the new workflow with minimal setup.
- Templates are data-driven: pass dictionaries for text tokens, slider ranges, toggle state, textures, and action payloads. `UITemplateDataBinder` handles conversion and WidgetFactory integration.
- Register templates with `UIScreenManager.register_template(id, preload("template.tscn"))` and activate them using `push_template(id, content_dictionary)`.
- Available templates: Dialog, Settings, Inventory, List, HUD overlay, and Loading screen. See `res://UI/Templates/README.md` for binding examples and recommended payload shapes.
- `MenuBuilder` remains for legacy schemas but is deprecated; prefer converting to templates for new UI.

### Integration Checklist

- Add required autoloads to the project settings before loading UI scenes.
- Instantiate layout containers through `WidgetFactory` to guarantee styling and dependency guards are applied consistently.
- Handle any error logs surfaced by the widgets—these indicate missing dependencies or incorrect setup.

## Screen Manager

- `UIScreenManager.gd` manages UI screen stacks with transition support.
- Register screens via `register_screen(id, scene)` and navigate with `push_screen`, `replace_screen`, `pop_screen`.
- Integrates with the shared transition library when a transition player is supplied.
- Publishes `UI_SCREEN_PUSHED` / `UI_SCREEN_POPPED` EventBus topics when available.
- Screens receive context via `receive_context`, `on_screen_entered`, `on_screen_exited`. Wire `InputService` actions inside these callbacks to react to user input, and use localization tokens for UI copy.

## HUD Shell & Input Glyphs

- `HUDShell.gd` registers pluggable HUD panels (`register_panel`, `show_panel`, `hide_panel`).
- `InputGlyphService.gd` stores glyph textures per device kind/action and listens to `InputService` device changes.
- Bind glyph icons via `register_action_icon(texture_rect, action)`; the HUD updates automatically when the active device changes.
- Panels can implement `receive_context`, `on_panel_shown`, and `on_panel_hidden` to respond to HUD events.

## Input Rebind UI

- `InputRebindPanel.tscn` provides a scrollable list of actions wired to `InputService`'s rebind API.
- Bindings persist through optional `SettingsService` keys (`input_bindings/<action>`); the panel reloads saved mappings on startup.
- Buttons use localization tokens (`ui/rebind/change`, `ui/rebind/waiting`) with fallbacks.
- Integrates seamlessly with `UIScreenManager` by adding the panel as a screen or HUD layer.
