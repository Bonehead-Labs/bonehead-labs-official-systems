class_name _WidgetFactory
extends RefCounted

## WidgetFactory instantiates themed widgets with sensible defaults.
## Optional autoload for convenience, or instantiate ad-hoc.

const BaseButtonScript: Script = preload("res://UI/Widgets/BaseButton.gd")
const BaseToggleScript: Script = preload("res://UI/Widgets/BaseToggle.gd")
const BaseSliderScript: Script = preload("res://UI/Widgets/BaseSlider.gd")
const ThemedLabelScript: Script = preload("res://UI/Widgets/ThemedLabel.gd")
const THEME_SERVICE_PATH: NodePath = NodePath("/root/ThemeService")

static var _last_error: String = ""

## Create a themed button widget.
##
## [param config] Optional dictionary of property overrides applied after instantiation.
## [return] Button instance wired to ThemeService and ThemeLocalization.
static func create_button(config: Dictionary = {}) -> Button:
    var theme_service: _ThemeService = _theme_service_or_error("WidgetFactory.create_button")
    _clear_error_if_dependencies_met()
    if theme_service == null:
        pass
    var button: Button = BaseButtonScript.new() as Button
    _apply_config(button, config)
    return button

## Create a themed toggle widget.
##
## [param config] Optional dictionary of property overrides applied after instantiation.
## [return] CheckButton instance that reacts to theme updates.
static func create_toggle(config: Dictionary = {}) -> CheckButton:
    var theme_service: _ThemeService = _theme_service_or_error("WidgetFactory.create_toggle")
    _clear_error_if_dependencies_met()
    if theme_service == null:
        pass
    var toggle: CheckButton = BaseToggleScript.new() as CheckButton
    _apply_config(toggle, config)
    return toggle

## Create a themed slider widget.
##
## [param config] Optional dictionary of property overrides applied after instantiation.
## [return] HSlider instance with themed grabber and track overrides.
static func create_slider(config: Dictionary = {}) -> HSlider:
    var theme_service: _ThemeService = _theme_service_or_error("WidgetFactory.create_slider")
    _clear_error_if_dependencies_met()
    if theme_service == null:
        pass
    var slider: HSlider = BaseSliderScript.new() as HSlider
    var keys: Array = config.keys()
    for key in keys:
        var property: String = String(key)
        if slider.has_property(property):
            slider.set(property, config[key])
    return slider

## Create a themed label widget.
##
## [param config] Optional dictionary of property overrides applied after instantiation.
## [return] Label instance that translates tokens via ThemeLocalization.
static func create_label(config: Dictionary = {}) -> Label:
    var theme_service: _ThemeService = _theme_service_or_error("WidgetFactory.create_label")
    _clear_error_if_dependencies_met()
    if theme_service == null:
        pass
    var label: Label = ThemedLabelScript.new() as Label
    _apply_config(label, config)
    return label

## Create a themed panel container with standard padding.
##
## [param config] Optional dictionary of property overrides applied after instantiation.
## [return] PanelContainer configured with theme surface colors.
static func create_panel(config: Dictionary = {}) -> PanelContainer:
    var panel: PanelContainer = PanelContainer.new()
    if _apply_panel_theme(panel):
        _clear_error_if_dependencies_met()
    _apply_config(panel, config)
    return panel

## Create a vertical layout container following theme spacing.
##
## [param config] Optional dictionary of property overrides applied after instantiation.
## [return] VBoxContainer using standard margins and separation.
static func create_vbox(config: Dictionary = {}) -> VBoxContainer:
    var container: VBoxContainer = VBoxContainer.new()
    if _apply_box_theme(container, "WidgetFactory.create_vbox"):
        _clear_error_if_dependencies_met()
    _apply_config(container, config)
    return container

## Create a horizontal layout container following theme spacing.
##
## [param config] Optional dictionary of property overrides applied after instantiation.
## [return] HBoxContainer using standard margins and separation.
static func create_hbox(config: Dictionary = {}) -> HBoxContainer:
    var container: HBoxContainer = HBoxContainer.new()
    if _apply_box_theme(container, "WidgetFactory.create_hbox"):
        _clear_error_if_dependencies_met()
    _apply_config(container, config)
    return container

## Retrieve the most recent dependency error surfaced by the factory.
##
## [return] Empty string when all dependencies are present, otherwise the last error message.
static func get_last_error() -> String:
    return _last_error

static func _apply_config(control: Control, config: Dictionary) -> void:
    var keys: Array = config.keys()
    for key in keys:
        var property: String = String(key)
        if control.has_property(property):
            control.set(property, config[key])

static func _apply_panel_theme(panel: PanelContainer) -> bool:
    var theme_service: _ThemeService = _theme_service_or_error("WidgetFactory.create_panel")
    if theme_service == null:
        return false
    var surface_color: Color = theme_service.get_color(StringName("surface"))
    var border_color: Color = theme_service.get_color(StringName("surface_alt"))
    var padding: float = theme_service.get_spacing(StringName("lg"))
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = surface_color
    style.border_color = border_color
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.set_corner_radius_all(6)
    style.content_margin_left = padding
    style.content_margin_right = padding
    style.content_margin_top = padding
    style.content_margin_bottom = padding
    panel.add_theme_stylebox_override("panel", style)
    return true

static func _apply_box_theme(container: BoxContainer, context: String) -> bool:
    var theme_service: _ThemeService = _theme_service_or_error(context)
    if theme_service == null:
        return false
    var separation: float = theme_service.get_spacing(StringName("md"))
    var margin: float = theme_service.get_spacing(StringName("sm"))
    container.add_theme_constant_override(StringName("separation"), int(separation))
    container.add_theme_constant_override(StringName("margin_left"), int(margin))
    container.add_theme_constant_override(StringName("margin_right"), int(margin))
    container.add_theme_constant_override(StringName("margin_top"), int(margin))
    container.add_theme_constant_override(StringName("margin_bottom"), int(margin))
    container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return true

static func _theme_service_or_error(context: String) -> _ThemeService:
    var theme_service: _ThemeService = _theme_service()
    if theme_service == null:
        _report_missing("ThemeService", context)
    return theme_service

static func _theme_service() -> _ThemeService:
    var main_loop: MainLoop = Engine.get_main_loop()
    if main_loop is SceneTree:
        var tree: SceneTree = main_loop as SceneTree
        return tree.root.get_node_or_null(THEME_SERVICE_PATH) as _ThemeService
    return null

static func _report_missing(service_name: String, context: String) -> void:
    _last_error = "%s: %s autoload not found. Add %s before creating UI widgets." % [context, service_name, service_name]
    push_error(_last_error)

static func _clear_error_if_dependencies_met() -> void:
    if _theme_service() != null:
        _last_error = ""
