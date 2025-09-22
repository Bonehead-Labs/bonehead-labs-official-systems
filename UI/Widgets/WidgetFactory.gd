class_name _WidgetFactory
extends RefCounted

## WidgetFactory instantiates themed widgets with sensible defaults.
## Optional autoload for convenience, or instantiate ad-hoc.

const BaseButtonScript = preload("res://UI/Widgets/BaseButton.gd")
const BaseToggleScript = preload("res://UI/Widgets/BaseToggle.gd")
const BaseSliderScript = preload("res://UI/Widgets/BaseSlider.gd")
const ThemedLabelScript = preload("res://UI/Widgets/ThemedLabel.gd")

static func create_button(config: Dictionary = {}) -> Button:
    var button := BaseButtonScript.new()
    _apply_config(button, config)
    return button

static func create_toggle(config: Dictionary = {}) -> CheckButton:
    var toggle := BaseToggleScript.new()
    _apply_config(toggle, config)
    return toggle

static func create_slider(config: Dictionary = {}) -> HSlider:
    var slider := BaseSliderScript.new()
    for key in config.keys():
        if slider.has_property(key):
            slider.set(key, config[key])
    return slider

static func create_label(config: Dictionary = {}) -> Label:
    var label := ThemedLabelScript.new()
    _apply_config(label, config)
    return label

static func _apply_config(control: Control, config: Dictionary) -> void:
    for key in config.keys():
        var property := String(key)
        if control.has_property(property):
            control.set(property, config[key])
