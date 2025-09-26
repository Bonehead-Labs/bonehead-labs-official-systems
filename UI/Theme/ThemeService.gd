class_name _ThemeService
extends Node

## ThemeService exposes runtime access to theme tokens and accessibility toggles.
## Add as an autoload named `ThemeService` to query colors, spacing, or high-contrast focus styles.

signal theme_changed()

var _tokens: ThemeTokens
var _use_high_contrast: bool = false
var _focus_style_cache: StyleBox = null
const DEFAULT_FOCUS_PATH: String = "res://UI/Theme/focus_outline_default.tres"
const HIGH_CONTRAST_FOCUS_PATH: String = "res://UI/Theme/focus_outline_high_contrast.tres"

func _ready() -> void:
    load_tokens("res://UI/Theme/default_theme.tokens.tres")

## Load theme tokens from a resource file
## 
## Loads theme tokens from a ThemeTokens resource file and
## invalidates cached styles to trigger theme updates.
## 
## [b]resource_path:[/b] Path to the ThemeTokens resource file
## 
## [b]Usage:[/b]
## [codeblock]
## # Load custom theme
## theme_service.load_tokens("res://themes/dark_theme.tokens.tres")
## [/codeblock]
func load_tokens(resource_path: String) -> void:
    if not ResourceLoader.exists(resource_path):
        push_warning("ThemeService: token resource not found at %s" % resource_path)
        return
        
    var loaded: Resource = ResourceLoader.load(resource_path)
    if loaded is ThemeTokens:
        _tokens = loaded
        _focus_style_cache = null
        emit_signal("theme_changed")
    else:
        push_warning("ThemeService: resource at %s is not ThemeTokens" % resource_path)

## Enable or disable high-contrast accessibility mode
## 
## Toggles high-contrast mode for better accessibility.
## Invalidates cached styles to trigger theme updates.
## 
## [b]enabled:[/b] true to enable high-contrast mode, false to disable
## 
## [b]Usage:[/b]
## [codeblock]
## # Enable accessibility mode
## theme_service.enable_high_contrast(true)
## [/codeblock]
func enable_high_contrast(enabled: bool) -> void:
    if _use_high_contrast == enabled:
        return
        
    _use_high_contrast = enabled
    _focus_style_cache = null
    emit_signal("theme_changed")

## Check if high-contrast mode is enabled
## 
## [b]Returns:[/b] true if high-contrast mode is active, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Check accessibility mode
## if theme_service.is_high_contrast_enabled():
##     # Use high-contrast colors
## [/codeblock]
func is_high_contrast_enabled() -> bool:
    return _use_high_contrast

## Get a color token from the theme
## 
## Retrieves a color value from the loaded theme tokens.
## Automatically uses high-contrast variant if enabled.
## 
## [b]color_name:[/b] Name of the color token to retrieve
## 
## [b]Returns:[/b] Color value or white if token not found
## 
## [b]Usage:[/b]
## [codeblock]
## # Get primary text color
## var text_color = theme_service.get_color("text_primary")
## label.add_theme_color_override("font_color", text_color)
## [/codeblock]
func get_color(color_name: StringName) -> Color:
    if _tokens and _tokens.has_color(color_name, _use_high_contrast):
        return _tokens.get_color(color_name, _use_high_contrast)
    return Color.WHITE

## Get a spacing token from the theme
## 
## Retrieves a spacing value in pixels from the loaded theme tokens.
## 
## [b]spacing_name:[/b] Name of the spacing token to retrieve
## 
## [b]Returns:[/b] Spacing value in pixels or 0.0 if token not found
## 
## [b]Usage:[/b]
## [codeblock]
## # Get margin spacing
## var margin = theme_service.get_spacing("margin_large")
## container.add_theme_constant_override("margin_left", margin)
## [/codeblock]
func get_spacing(spacing_name: StringName) -> float:
    return _tokens.get_spacing(spacing_name) if _tokens else 0.0

## Get a font size token from the theme
## 
## Retrieves a font size value in points from the loaded theme tokens.
## 
## [b]size_name:[/b] Name of the font size token to retrieve
## 
## [b]Returns:[/b] Font size in points or 16 if token not found
## 
## [b]Usage:[/b]
## [codeblock]
## # Get body text size
## var font_size = theme_service.get_font_size("body")
## label.add_theme_font_size_override("font_size", font_size)
## [/codeblock]
func get_font_size(size_name: StringName) -> int:
    return _tokens.get_font_size(size_name) if _tokens else 16

## Get the preferred font resource path
## 
## Retrieves the path to the preferred font resource from theme tokens.
## 
## [b]Returns:[/b] Font resource path or empty string if not found
## 
## [b]Usage:[/b]
## [codeblock]
## # Load preferred font
## var font_path = theme_service.get_font_path()
## if font_path != "":
##     var font = load(font_path)
##     label.add_theme_font_override("font", font)
## [/codeblock]
func get_font_path() -> String:
    return _tokens.get_font_path() if _tokens else ""

## Get a StyleBox configured for focus outlines
## 
## Returns a StyleBox suitable for focus indicators on UI elements.
## Uses cached style or creates one from theme tokens. Automatically
## switches between normal and high-contrast variants.
## 
## [b]Returns:[/b] StyleBox configured for focus outlines
## 
## [b]Usage:[/b]
## [codeblock]
## # Apply focus style to button
## var focus_style = theme_service.get_focus_stylebox()
## button.add_theme_stylebox_override("focus", focus_style)
## [/codeblock]
func get_focus_stylebox() -> StyleBox:
    if _focus_style_cache:
        return _focus_style_cache
        
    var resource_path: String = HIGH_CONTRAST_FOCUS_PATH if _use_high_contrast else DEFAULT_FOCUS_PATH
    if ResourceLoader.exists(resource_path):
        var style: Resource = ResourceLoader.load(resource_path)
        if style is StyleBox:
            _focus_style_cache = style
            
    if _focus_style_cache == null:
        var style: StyleBoxFlat = StyleBoxFlat.new()
        var outline_color: Color = _tokens.get_focus_color(_use_high_contrast) if _tokens else Color(0.5, 0.5, 1.0)
        style.set_border_width_all(int(_tokens.get_focus_outline_width() if _tokens else 2.0))
        style.set_border_color(outline_color)
        style.draw_center = false
        style.set_corner_radius_all(int(_tokens.get_focus_corner_radius() if _tokens else 4.0))
        _focus_style_cache = style
        
    return _focus_style_cache
