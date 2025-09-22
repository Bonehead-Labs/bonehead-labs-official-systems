class_name _ThemeService
extends Node

## ThemeService exposes runtime access to theme tokens and accessibility toggles.
## Add as an autoload named `ThemeService` to query colors, spacing, or high-contrast focus styles.

var _tokens: ThemeTokens
var _use_high_contrast: bool = false
var _focus_style_cache: StyleBox = null

func _ready() -> void:
    load_tokens("res://UI/Theme/default_theme.tokens.tres")

## Loads a theme token resource from the supplied path.
func load_tokens(resource_path: String) -> void:
    if not ResourceLoader.exists(resource_path):
        push_warning("ThemeService: token resource not found at %s" % resource_path)
        return
    var loaded := ResourceLoader.load(resource_path)
    if loaded is ThemeTokens:
        _tokens = loaded
        _focus_style_cache = null
    else:
        push_warning("ThemeService: resource at %s is not ThemeTokens" % resource_path)

## Enables or disables the high-contrast palette.
func enable_high_contrast(enabled: bool) -> void:
    if _use_high_contrast == enabled:
        return
    _use_high_contrast = enabled
    _focus_style_cache = null

## Returns true when high-contrast mode is active.
func is_high_contrast_enabled() -> bool:
    return _use_high_contrast

## Fetches a color token. Falls back to white when missing.
func get_color(name: StringName) -> Color:
    if _tokens and _tokens.has_color(name, _use_high_contrast):
        return _tokens.get_color(name, _use_high_contrast)
    return Color.WHITE

## Fetches a spacing token in pixels.
func get_spacing(name: StringName) -> float:
    return _tokens.get_spacing(name) if _tokens else 0.0

## Fetches a font size token in points.
func get_font_size(name: StringName) -> int:
    return _tokens.get_font_size(name) if _tokens else 16

## Returns the preferred font resource path, or empty string.
func get_font_path() -> String:
    return _tokens.get_font_path() if _tokens else ""

## Returns a StyleBox configured for focus outlines.
func get_focus_stylebox() -> StyleBox:
    if _focus_style_cache:
        return _focus_style_cache
    var style := StyleBoxFlat.new()
    var outline_color := _tokens.get_focus_color(_use_high_contrast) if _tokens else Color(0.5, 0.5, 1.0)
    style.set_border_width_all(int(_tokens.get_focus_outline_width() if _tokens else 2.0))
    style.set_border_color(outline_color)
    style.draw_center = false
    style.set_corner_radius_all(int(_tokens.get_focus_corner_radius() if _tokens else 4.0))
    _focus_style_cache = style
    return _focus_style_cache
