class_name ThemeTokens
extends Resource

## ThemeTokens encapsulates design tokens for colors, typography, and spacing.
## Consumers should reference this resource via `ThemeService` for runtime lookups.

@export var palette_primary: Dictionary = {
    StringName("background"): Color(0.117, 0.122, 0.161, 1.0),
    StringName("surface"): Color(0.176, 0.184, 0.247, 1.0),
    StringName("surface_alt"): Color(0.207, 0.219, 0.290, 1.0),
    StringName("accent"): Color(0.498, 0.353, 0.941, 1.0),
    StringName("accent_alt"): Color(0.173, 0.718, 0.490, 1.0),
    StringName("text_primary"): Color(0.996, 0.998, 0.996, 1.0),
    StringName("text_muted"): Color(0.753, 0.773, 0.847, 1.0)
}

@export var palette_high_contrast: Dictionary = {
    StringName("background"): Color(0.0, 0.0, 0.0, 1.0),
    StringName("surface"): Color(0.078, 0.078, 0.078, 1.0),
    StringName("surface_alt"): Color(0.121, 0.121, 0.121, 1.0),
    StringName("accent"): Color(1.0, 0.706, 0.0, 1.0),
    StringName("accent_alt"): Color(0.035, 0.875, 1.0, 1.0),
    StringName("text_primary"): Color(1.0, 1.0, 1.0, 1.0),
    StringName("text_muted"): Color(0.753, 0.753, 0.753, 1.0)
}

@export var typography: Dictionary = {
    StringName("font_family"): "",
    StringName("sizes"): {
        StringName("display"): 32,
        StringName("title"): 24,
        StringName("subtitle"): 20,
        StringName("body"): 16,
        StringName("caption"): 13
    }
}

@export var spacing: Dictionary = {
    StringName("xs"): 4.0,
    StringName("sm"): 8.0,
    StringName("md"): 12.0,
    StringName("lg"): 16.0,
    StringName("xl"): 24.0
}

@export var focus: Dictionary = {
    StringName("outline_width"): 3.0,
    StringName("corner_radius"): 6.0,
    StringName("default_color"): Color(0.498, 0.353, 0.941, 1.0),
    StringName("high_contrast_color"): Color(1.0, 0.706, 0.0, 1.0)
}

func has_color(name: StringName, high_contrast: bool) -> bool:
    var table := palette_high_contrast if high_contrast else palette_primary
    return table.has(name)

func get_color(name: StringName, high_contrast: bool) -> Color:
    var table := palette_high_contrast if high_contrast else palette_primary
    return table.get(name, Color.WHITE)

func get_spacing(token: StringName) -> float:
    return float(spacing.get(token, 0.0))

func get_font_size(token: StringName) -> int:
    var sizes := typography.get(StringName("sizes"), {})
    return int(sizes.get(token, 16))

func get_font_path() -> String:
    return String(typography.get(StringName("font_family"), ""))

func get_focus_color(high_contrast: bool) -> Color:
    return focus.get(StringName("high_contrast_color"), Color.WHITE) if high_contrast else focus.get(StringName("default_color"), Color.WHITE)

func get_focus_outline_width() -> float:
    return float(focus.get(StringName("outline_width"), 2.0))

func get_focus_corner_radius() -> float:
    return float(focus.get(StringName("corner_radius"), 4.0))
