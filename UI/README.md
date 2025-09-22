# UI System

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

All widgets subscribe to `ThemeService.theme_changed` so they react to palette updates and high-contrast toggles automatically.

## Screen Manager

- `UIScreenManager.gd` manages UI screen stacks with transition support.
- Register screens via `register_screen(id, scene)` and navigate with `push_screen`, `replace_screen`, `pop_screen`.
- Integrates with the shared transition library when a transition player is supplied.
- Publishes `UI_SCREEN_PUSHED` / `UI_SCREEN_POPPED` EventBus topics when available.
