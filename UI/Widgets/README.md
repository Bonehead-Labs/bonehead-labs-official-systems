# Widget Library

## Available Controls

- `BaseButton.gd`: Button with theme-driven typography and localization token support.
- `BaseToggle.gd`: CheckButton variant adhering to ThemeService colors.
- `BaseSlider.gd`: HSlider with themed grabber/track.
- `ThemedLabel.gd`: Label that translates tokens and applies theme text colors.
- `WidgetFactory.gd`: Static helpers to instantiate the controls with optional configuration dictionaries.

## Usage

```gdscript
var button := WidgetFactory.create_button({
    "label_token": StringName("ui/menu/start"),
    "label_fallback": "Start"
})
add_child(button)
```

All widgets respond to `ThemeService.theme_changed` (triggered by token swaps or high-contrast toggles) and update their appearance automatically.

The template system (`res://UI/Templates/`) builds on these controls. Template scripts call `WidgetFactory` when generating dynamic content (list entries, settings controls, inventory slots), ensuring developer-authored templates inherit the same theming and accessibility defaults.
