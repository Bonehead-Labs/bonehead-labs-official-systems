class_name _MenuBuilder
extends Node

## MenuBuilder composes reusable UI shells from dictionary-based menu schemas.
##
## Schemas describe the shell scene, sections, controls, and action bindings.
## Each control is instantiated through WidgetFactory helpers to enforce theme
## consistency. Actions connect to exported callables, and the builder performs
## validation so misconfigurations are surfaced through descriptive errors.
##
## [b]Usage:[/b]
## [codeblock]
## var builder := _MenuBuilder.new()
## builder.action_callbacks = {
##     StringName("start_game"): Callable(self, "_on_start_game"),
##     StringName("quit"): Callable(self, "_on_quit")
## }
## var menu := builder.build_menu(load("res://UI/Layouts/menu_schema.example.gd").MENU_SCHEMA)
## add_child(menu)
## [/codeblock]

const THEME_SERVICE_PATH: NodePath = NodePath("/root/ThemeService")
const THEME_LOCALIZATION_PATH: NodePath = NodePath("/root/ThemeLocalization")

const SUPPORTED_LAYOUTS: Dictionary = {
    StringName("vbox"): true,
    StringName("hbox"): true,
    StringName("panel"): true
}

const SUPPORTED_FACTORIES: Dictionary = {
    StringName("label"): true,
    StringName("button"): true,
    StringName("toggle"): true,
    StringName("slider"): true,
    StringName("panel"): true,
    StringName("vbox"): true,
    StringName("hbox"): true
}

## Dictionary of action callbacks supplied prior to building menus.
##
## [b]Default:[/b] {} (no callbacks registered)
##
## Keys are action identifiers defined in the schema's `actions` section, and
## values are Callables invoked when the bound UI control emits its signal.
@export var action_callbacks: Dictionary = {}

var _last_error: String = ""
var _actions_config: Dictionary = {}
var _control_registry: Dictionary = {}
var _active_callbacks: Dictionary = {}

## Build a menu hierarchy from a validated schema.
##
## [b]config:[/b] Dictionary describing the menu schema.
## [b]Returns:[/b] Control root of the assembled menu, or null on failure.
func build_menu(config: Dictionary) -> Control:
    _last_error = ""
    var schema_errors: Array[String] = validate_config(config)
    if not schema_errors.is_empty():
        for message in schema_errors:
            _record_error(message)
        return null
    if not _check_dependencies():
        return null
    var callbacks: Dictionary = _normalize_callbacks(action_callbacks)
    var binding_errors: Array[String] = validate_bindings(config, callbacks)
    if not binding_errors.is_empty():
        for message in binding_errors:
            _record_error(message)
        return null
    var actions_variant: Variant = config.get("actions", {})
    _prepare_state(actions_variant, callbacks)
    var shell_path: String = String(config.get("shell_scene", ""))
    var shell: Control = _instantiate_shell(shell_path)
    if shell == null:
        return null
    var shell_config_variant: Variant = config.get("shell")
    if shell_config_variant is Dictionary:
        var shell_config: Dictionary = shell_config_variant as Dictionary
        _apply_header(shell, shell_config)
    var sections_variant: Variant = config.get("sections", [])
    if sections_variant is Array:
        var sections: Array = sections_variant as Array
        var body: Control = _build_body(sections)
        if body != null:
            _assign_body(shell, body)
    if shell_config_variant is Dictionary:
        _apply_footer(shell, shell_config_variant as Dictionary)
    return shell

## Validate a menu schema before building.
##
## [b]config:[/b] Dictionary describing the menu.
## [b]Returns:[/b] Array of error strings; empty when the schema is valid.
func validate_config(config: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    if config.is_empty():
        errors.append("MenuBuilder: config dictionary is empty.")
    if not config.has("shell_scene"):
        errors.append("MenuBuilder: 'shell_scene' is required and must reference a PackedScene path.")
    else:
        var scene_path: String = String(config.get("shell_scene", ""))
        if scene_path.is_empty():
            errors.append("MenuBuilder: 'shell_scene' cannot be an empty string.")
        elif not ResourceLoader.exists(scene_path, "PackedScene"):
            errors.append("MenuBuilder: shell scene '%s' could not be found." % scene_path)
    if config.has("shell") and not (config.get("shell") is Dictionary):
        errors.append("MenuBuilder: 'shell' must be a Dictionary when provided.")
    var actions_variant: Variant = config.get("actions", {})
    var actions: Dictionary = {}
    if actions_variant is Dictionary:
        actions = actions_variant as Dictionary
        errors.append_array(_validate_actions(actions))
    elif actions_variant != null:
        errors.append("MenuBuilder: 'actions' must be a Dictionary.")
    var control_ids: Dictionary = {}
    var sections_variant: Variant = config.get("sections", [])
    errors.append_array(_validate_sections(sections_variant, actions, control_ids))
    var shell_variant: Variant = config.get("shell")
    if shell_variant is Dictionary:
        var shell_dict: Dictionary = shell_variant as Dictionary
        if shell_dict.has("header"):
            var header_variant: Variant = shell_dict.get("header")
            if header_variant is Dictionary:
                var header_dict: Dictionary = header_variant as Dictionary
                var header_controls: Variant = header_dict.get("controls")
                errors.append_array(_validate_controls(header_controls, actions, control_ids, "shell.header"))
            elif header_variant != null:
                errors.append("MenuBuilder: 'shell.header' must be a Dictionary.")
        if shell_dict.has("footer"):
            var footer_variant: Variant = shell_dict.get("footer")
            if footer_variant is Dictionary:
                var footer_dict: Dictionary = footer_variant as Dictionary
                var mode_variant: Variant = footer_dict.get("mode", "container")
                if mode_variant != null and not (mode_variant is String or mode_variant is StringName):
                    errors.append("MenuBuilder: 'shell.footer.mode' must be a String or StringName.")
                elif mode_variant != null:
                    var mode_name: String = String(mode_variant).to_lower()
                    if mode_name != "container" and mode_name != "actions":
                        errors.append("MenuBuilder: 'shell.footer.mode' must be 'container' or 'actions'.")
                var footer_controls: Variant = footer_dict.get("controls")
                errors.append_array(_validate_controls(footer_controls, actions, control_ids, "shell.footer"))
            elif footer_variant != null:
                errors.append("MenuBuilder: 'shell.footer' must be a Dictionary.")
    return errors

## Validate that callbacks exist for each declared action.
##
## [b]config:[/b] Menu schema dictionary.
## [b]callbacks_override:[/b] Optional dictionary of callables keyed by action identifier.
## [b]Returns:[/b] Array of error strings for missing or invalid callbacks.
func validate_bindings(config: Dictionary, callbacks_override: Dictionary = {}) -> Array[String]:
    var errors: Array[String] = []
    var actions_variant: Variant = config.get("actions", {})
    if not (actions_variant is Dictionary):
        return errors
    var actions: Dictionary = actions_variant as Dictionary
    var callback_source: Dictionary = callbacks_override
    if callback_source.is_empty():
        callback_source = _normalize_callbacks(action_callbacks)
    for key in actions.keys():
        var action_id: StringName = _to_string_name(key)
        if action_id == StringName():
            continue
        var action_data_variant: Variant = actions[key]
        if not (action_data_variant is Dictionary):
            continue
        var action_data: Dictionary = action_data_variant as Dictionary
        var callback_descriptor: Variant = action_data.get("callback")
        if callback_descriptor == null:
            errors.append("MenuBuilder: callback missing for action '%s'." % action_id)
            continue
        var callable: Callable = _resolve_callback_from_source(callback_descriptor, callback_source)
        if callable.is_null() or not callable.is_valid():
            errors.append("MenuBuilder: callback binding is invalid for action '%s'." % action_id)
    return errors

## Retrieve the last recorded error message.
##
## [b]Returns:[/b] Last error string or empty when no errors have been recorded.
func get_last_error() -> String:
    return _last_error

## Fetch a built control by identifier.
##
## [b]control_id:[/b] Identifier declared in a control definition.
## [b]Returns:[/b] Control instance when found, otherwise null.
func get_control(control_id: StringName) -> Control:
    if _control_registry.has(control_id):
        return _control_registry[control_id] as Control
    for key in _control_registry.keys():
        if _to_string_name(key) == control_id:
            return _control_registry[key] as Control
    return null

## Register a single callback for an action identifier.
##
## [b]action_id:[/b] Identifier matching the action entry in the schema.
## [b]callback:[/b] Callable invoked when the action fires.
func register_callback(action_id: StringName, callback: Callable) -> void:
    if action_id == StringName() or callback.is_null() or not callback.is_valid():
        _record_error("MenuBuilder: cannot register callback; invalid identifier or callable.")
        return
    action_callbacks[action_id] = callback

func _prepare_state(actions_variant: Variant, callbacks: Dictionary) -> void:
    _actions_config.clear()
    _control_registry.clear()
    _active_callbacks = callbacks.duplicate(true)
    if not (actions_variant is Dictionary):
        return
    var actions: Dictionary = actions_variant as Dictionary
    for key in actions.keys():
        var action_id: StringName = _to_string_name(key)
        if action_id == StringName():
            continue
        var data_variant: Variant = actions[key]
        if data_variant is Dictionary:
            _actions_config[action_id] = (data_variant as Dictionary).duplicate(true)
        elif data_variant is Callable:
            _actions_config[action_id] = {"callback": data_variant}
        else:
            _actions_config[action_id] = {}

func _check_dependencies() -> bool:
    var missing: Array[StringName] = []
    if _theme_service() == null:
        missing.append(StringName("ThemeService"))
    if _theme_localization() == null:
        missing.append(StringName("ThemeLocalization"))
    if missing.is_empty():
        return true
    for service_name in missing:
        _record_error("MenuBuilder: %s autoload not found. Add %s before building menus." % [service_name, service_name])
    return false

func _instantiate_shell(scene_path: String) -> Control:
    if scene_path.is_empty():
        _record_error("MenuBuilder: cannot instantiate shell without a scene path.")
        return null
    var resource: Resource = ResourceLoader.load(scene_path)
    if resource == null:
        _record_error("MenuBuilder: failed to load shell scene '%s'." % scene_path)
        return null
    var packed_scene: PackedScene = resource as PackedScene
    if packed_scene == null:
        _record_error("MenuBuilder: shell scene '%s' is not a PackedScene." % scene_path)
        return null
    var instance: Node = packed_scene.instantiate()
    if not (instance is Control):
        _record_error("MenuBuilder: shell scene '%s' must inherit from Control." % scene_path)
        instance.queue_free()
        return null
    return instance as Control

func _apply_header(shell: Control, shell_config: Dictionary) -> void:
    if not shell_config.has("header"):
        return
    var header_variant: Variant = shell_config.get("header")
    if not (header_variant is Dictionary):
        return
    var header: Dictionary = header_variant as Dictionary
    if shell is _DialogShell:
        var dialog: _DialogShell = shell as _DialogShell
        if header.has("title") and header.get("title") is Dictionary:
            var title_text: String = _resolve_text(header.get("title") as Dictionary)
            if not title_text.is_empty():
                dialog.set_title(title_text)
        if header.has("description") and header.get("description") is Dictionary:
            var description_text: String = _resolve_text(header.get("description") as Dictionary)
            dialog.set_description(description_text)
    if header.has("controls"):
        var header_slot: Control = _get_header_slot(shell)
        if header_slot != null:
            var controls: Array[Control] = _build_control_list(header.get("controls"))
            for control_element in controls:
                header_slot.add_child(control_element)

func _build_body(sections: Array) -> Control:
    var body: VBoxContainer = _WidgetFactory.create_vbox({}) as VBoxContainer
    var has_content: bool = false
    for section_variant in sections:
        if not (section_variant is Dictionary):
            continue
        var section: Control = _build_section(section_variant as Dictionary)
        if section != null:
            body.add_child(section)
            has_content = true
    if has_content:
        return body
    body.queue_free()
    return null

func _assign_body(shell: Control, body: Control) -> void:
    if shell is _PanelShell:
        (shell as _PanelShell).set_body(body)
    else:
        shell.add_child(body)

func _apply_footer(shell: Control, shell_config: Dictionary) -> void:
    if not shell_config.has("footer"):
        return
    var footer_variant: Variant = shell_config.get("footer")
    if not (footer_variant is Dictionary):
        return
    var footer: Dictionary = footer_variant as Dictionary
    var controls: Array[Control] = _build_control_list(footer.get("controls"))
    if controls.is_empty():
        return
    var mode_name: String = String(footer.get("mode", "container")).to_lower()
    if shell is _DialogShell and mode_name == "actions":
        (shell as _DialogShell).set_actions(controls)
        return
    var layout_kind: String = String(footer.get("layout", "hbox"))
    var container: Control = _create_container(layout_kind)
    if container == null:
        container = _WidgetFactory.create_hbox({}) as Control
    for control_element in controls:
        container.add_child(control_element)
    if shell is _PanelShell:
        (shell as _PanelShell).set_footer(container)
    else:
        shell.add_child(container)

func _build_section(section: Dictionary) -> Control:
    var layout_key: String = String(section.get("layout", "vbox"))
    var container: Control = _create_container(layout_key)
    if container == null:
        container = _WidgetFactory.create_vbox({}) as Control
    var section_id: StringName = _to_string_name(section.get("id", StringName()))
    if section_id != StringName():
        container.name = String(section_id)
        _control_registry[section_id] = container
    if section.has("title") and section.get("title") is Dictionary:
        var title_dict: Dictionary = section.get("title") as Dictionary
        var label_config: Dictionary = {
            "label_token": _to_string_name(title_dict.get("token", StringName())),
            "label_fallback": String(title_dict.get("fallback", ""))
        }
        var title_config_variant: Variant = title_dict.get("config")
        if title_config_variant is Dictionary:
            var title_config: Dictionary = title_config_variant as Dictionary
            for key in title_config.keys():
                label_config[key] = title_config[key]
        var title_label: Label = _WidgetFactory.create_label(label_config) as Label
        container.add_child(title_label)
    var controls: Array[Control] = _build_control_list(section.get("controls"))
    for control_element in controls:
        container.add_child(control_element)
    return container

func _build_control_list(raw_controls: Variant) -> Array[Control]:
    var controls: Array[Control] = []
    if not (raw_controls is Array):
        return controls
    var controls_array: Array = raw_controls as Array
    var index: int = 0
    for entry_variant in controls_array:
        if entry_variant is Dictionary:
            var control: Control = _build_control(entry_variant as Dictionary, index)
            if control != null:
                controls.append(control)
        else:
            _record_error("MenuBuilder: control entry at index %d must be a Dictionary." % index)
        index += 1
    return controls

func _build_control(entry: Dictionary, index: int) -> Control:
    if not entry.has("factory"):
        _record_error("MenuBuilder: control at index %d is missing 'factory'." % index)
        return null
    var factory_id: StringName = _to_string_name(entry.get("factory", StringName()))
    if factory_id == StringName():
        _record_error("MenuBuilder: control at index %d has an empty 'factory'." % index)
        return null
    var config_variant: Variant = entry.get("config", {})
    var config_dict: Dictionary = {}
    if config_variant == null:
        config_dict = {}
    elif config_variant is Dictionary:
        config_dict = config_variant as Dictionary
    else:
        _record_error("MenuBuilder: control '%s' has invalid config; expected Dictionary." % factory_id)
        config_dict = {}
    var control: Control = _invoke_factory(factory_id, config_dict)
    if control == null:
        _record_error("MenuBuilder: factory '%s' is not supported." % factory_id)
        return null
    var control_id: StringName = _to_string_name(entry.get("id", StringName()))
    if control_id != StringName():
        if _control_registry.has(control_id):
            _record_error("MenuBuilder: duplicate control id '%s' encountered." % control_id)
        else:
            _control_registry[control_id] = control
            control.name = String(control_id)
    elif entry.has("name"):
        var name_value: String = String(entry.get("name", ""))
        if not name_value.is_empty():
            control.name = name_value
    if entry.has("action"):
        var action_id: StringName = _to_string_name(entry.get("action", StringName()))
        if action_id != StringName():
            _wire_action(control, action_id)
    return control

func _wire_action(control: Control, action_id: StringName) -> void:
    if not _actions_config.has(action_id):
        _record_error("MenuBuilder: control '%s' references undefined action '%s'." % [control.name, action_id])
        return
    var action_data: Dictionary = _actions_config[action_id] as Dictionary
    var signal_name: StringName = _resolve_signal_name(action_data, control)
    if signal_name == StringName():
        _record_error("MenuBuilder: action '%s' is missing a signal binding." % action_id)
        return
    if not control.has_signal(signal_name):
        _record_error("MenuBuilder: control '%s' does not provide signal '%s' required by action '%s'." % [control.name, signal_name, action_id])
        return
    var callback_descriptor: Variant = action_data.get("callback")
    var callable: Callable = _resolve_callback(callback_descriptor)
    if callable.is_null() or not callable.is_valid():
        _record_error("MenuBuilder: callback for action '%s' is not available." % action_id)
        return
    var payload: Variant = action_data.get("payload", null)
    var bound_callable: Callable = callable
    if payload != null:
        bound_callable = callable.bind(payload)
    if control.is_connected(signal_name, bound_callable):
        return
    var err: int = control.connect(signal_name, bound_callable)
    if err != OK:
        _record_error("MenuBuilder: failed to connect action '%s' (error %d)." % [action_id, err])

func _invoke_factory(factory_id: StringName, config: Dictionary) -> Control:
    match factory_id:
        StringName("label"):
            return _WidgetFactory.create_label(config) as Control
        StringName("button"):
            return _WidgetFactory.create_button(config) as Control
        StringName("toggle"):
            return _WidgetFactory.create_toggle(config) as Control
        StringName("slider"):
            return _WidgetFactory.create_slider(config) as Control
        StringName("panel"):
            return _WidgetFactory.create_panel(config) as Control
        StringName("vbox"):
            return _WidgetFactory.create_vbox(config) as Control
        StringName("hbox"):
            return _WidgetFactory.create_hbox(config) as Control
        _:
            return null

func _create_container(layout_kind: String) -> Control:
    var key: String = layout_kind.to_lower()
    match key:
        "vbox":
            return _WidgetFactory.create_vbox({}) as Control
        "hbox":
            return _WidgetFactory.create_hbox({}) as Control
        "panel":
            return _WidgetFactory.create_panel({}) as Control
        _:
            return null

func _validate_sections(sections_variant: Variant, actions: Dictionary, control_ids: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    if sections_variant == null:
        return errors
    if not (sections_variant is Array):
        errors.append("MenuBuilder: 'sections' must be an Array.")
        return errors
    var sections: Array = sections_variant as Array
    var index: int = 0
    for section_variant in sections:
        if not (section_variant is Dictionary):
            errors.append("MenuBuilder: sections[%d] must be a Dictionary." % index)
            index += 1
            continue
        var section_dict: Dictionary = section_variant as Dictionary
        if section_dict.has("layout"):
            var layout_value: Variant = section_dict.get("layout")
            var layout_id: StringName = _to_string_name(layout_value)
            if layout_id == StringName() or not SUPPORTED_LAYOUTS.has(layout_id):
                errors.append("MenuBuilder: sections[%d].layout '%s' is not supported." % [index, layout_value])
        if section_dict.has("title") and not (section_dict.get("title") is Dictionary):
            errors.append("MenuBuilder: sections[%d].title must be a Dictionary." % index)
        errors.append_array(_validate_controls(section_dict.get("controls"), actions, control_ids, "sections[%d]" % index))
        index += 1
    return errors

func _validate_controls(raw_controls: Variant, actions: Dictionary, control_ids: Dictionary, context: String) -> Array[String]:
    var errors: Array[String] = []
    if raw_controls == null:
        return errors
    if not (raw_controls is Array):
        errors.append("MenuBuilder: %s.controls must be an Array." % context)
        return errors
    var controls_array: Array = raw_controls as Array
    var index: int = 0
    for entry_variant in controls_array:
        if not (entry_variant is Dictionary):
            errors.append("MenuBuilder: %s.controls[%d] must be a Dictionary." % [context, index])
            index += 1
            continue
        var entry: Dictionary = entry_variant as Dictionary
        var factory_id: StringName = _to_string_name(entry.get("factory", StringName()))
        if factory_id == StringName():
            errors.append("MenuBuilder: %s.controls[%d] requires a 'factory'." % [context, index])
        elif not SUPPORTED_FACTORIES.has(factory_id):
            errors.append("MenuBuilder: %s.controls[%d] uses unsupported factory '%s'." % [context, index, factory_id])
        if entry.has("config") and not (entry.get("config") is Dictionary):
            errors.append("MenuBuilder: %s.controls[%d].config must be a Dictionary." % [context, index])
        if entry.has("id"):
            var control_id: StringName = _to_string_name(entry.get("id", StringName()))
            if control_id == StringName():
                errors.append("MenuBuilder: %s.controls[%d] has an empty id." % [context, index])
            elif control_ids.has(control_id):
                errors.append("MenuBuilder: duplicate control id '%s' detected." % control_id)
            else:
                control_ids[control_id] = true
        if entry.has("action"):
            var action_id: StringName = _to_string_name(entry.get("action", StringName()))
            if action_id == StringName():
                errors.append("MenuBuilder: %s.controls[%d] defines an empty action id." % [context, index])
            elif not _actions_dictionary_has(actions, action_id):
                errors.append("MenuBuilder: %s.controls[%d] references unknown action '%s'." % [context, index, action_id])
        index += 1
    return errors

func _validate_actions(actions: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    var seen: Dictionary = {}
    for key in actions.keys():
        var action_id: StringName = _to_string_name(key)
        if action_id == StringName():
            errors.append("MenuBuilder: action keys must be strings or StringNames.")
            continue
        if seen.has(action_id):
            errors.append("MenuBuilder: duplicate action id '%s'." % action_id)
            continue
        seen[action_id] = true
        var data_variant: Variant = actions[key]
        if not (data_variant is Dictionary):
            errors.append("MenuBuilder: action '%s' must be a Dictionary." % action_id)
            continue
        var data: Dictionary = data_variant as Dictionary
        if not data.has("callback"):
            errors.append("MenuBuilder: action '%s' is missing 'callback'." % action_id)
        elif not ((data.get("callback") is String) or (data.get("callback") is StringName) or (data.get("callback") is Callable)):
            errors.append("MenuBuilder: action '%s' callback must be a StringName or Callable." % action_id)
        if data.has("signal") and not ((data.get("signal") is String) or (data.get("signal") is StringName)):
            errors.append("MenuBuilder: action '%s' signal must be a String or StringName." % action_id)
    return errors

func _resolve_signal_name(action_data: Dictionary, control: Control) -> StringName:
    var specified: Variant = action_data.get("signal")
    var signal_id: StringName = _to_string_name(specified)
    if signal_id != StringName():
        return signal_id
    if control is Button:
        return StringName("pressed")
    if control is CheckButton:
        return StringName("toggled")
    if control is Range:
        return StringName("value_changed")
    return StringName()

func _resolve_callback(descriptor: Variant) -> Callable:
    return _resolve_callback_from_source(descriptor, _active_callbacks)

func _resolve_callback_from_source(descriptor: Variant, callbacks_source: Dictionary) -> Callable:
    if descriptor is Callable:
        return descriptor
    var callback_id: StringName = _to_string_name(descriptor)
    if callback_id == StringName():
        return Callable()
    if callbacks_source.has(callback_id):
        var stored_value: Variant = callbacks_source[callback_id]
        if stored_value is Callable:
            return stored_value as Callable
    for key in callbacks_source.keys():
        if _to_string_name(key) == callback_id:
            var candidate: Variant = callbacks_source[key]
            if candidate is Callable:
                return candidate as Callable
    return Callable()

func _normalize_callbacks(source: Dictionary) -> Dictionary:
    var normalized: Dictionary = {}
    for key in source.keys():
        var action_id: StringName = _to_string_name(key)
        var value: Variant = source[key]
        if action_id != StringName() and value is Callable:
            var callable_value: Callable = value as Callable
            if callable_value.is_valid():
                normalized[action_id] = callable_value
    return normalized

func _resolve_text(entry: Dictionary) -> String:
    if entry.has("text"):
        return String(entry.get("text", ""))
    var token: StringName = _to_string_name(entry.get("token", StringName()))
    var fallback: String = String(entry.get("fallback", ""))
    if token == StringName():
        return fallback
    var localization: _ThemeLocalization = _theme_localization()
    if localization != null:
        return localization.translate(token, fallback)
    if fallback.is_empty():
        _record_error("MenuBuilder: ThemeLocalization missing; unable to translate token '%s'." % token)
    return fallback

func _get_header_slot(shell: Control) -> Control:
    if shell is _PanelShell:
        return (shell as _PanelShell).get_header_slot()
    return null

func _actions_dictionary_has(actions: Dictionary, action_id: StringName) -> bool:
    if actions.has(action_id):
        return true
    for key in actions.keys():
        if _to_string_name(key) == action_id:
            return true
    return false

func _theme_service() -> _ThemeService:
    var tree: SceneTree = _scene_tree()
    if tree == null:
        return null
    return tree.root.get_node_or_null(THEME_SERVICE_PATH) as _ThemeService

func _theme_localization() -> _ThemeLocalization:
    var tree: SceneTree = _scene_tree()
    if tree == null:
        return null
    return tree.root.get_node_or_null(THEME_LOCALIZATION_PATH) as _ThemeLocalization

func _scene_tree() -> SceneTree:
    var main_loop: MainLoop = Engine.get_main_loop()
    if main_loop is SceneTree:
        return main_loop as SceneTree
    return null

func _to_string_name(value: Variant) -> StringName:
    if value is StringName:
        return value
    if value is String:
        var text: String = String(value)
        if text.is_empty():
            return StringName()
        return StringName(text)
    return StringName()

func _record_error(message: String) -> void:
    if _last_error.is_empty():
        _last_error = message
    push_error(message)
