class_name _InputRebindPanel
extends Control

## InputRebindPanel provides a UI for remapping actions via InputService.

@export var actions: Array[StringName] = []
@export var container_path: NodePath = NodePath("ScrollContainer/ActionList")
@export var label_prefix: String = "input/action/"

const INPUT_SERVICE_PATH: NodePath = NodePath("/root/InputService")
const SETTINGS_SERVICE_PATH: NodePath = NodePath("/root/SettingsService")
const THEME_SERVICE_PATH: NodePath = NodePath("/root/ThemeService")
const LOCALIZATION_PATH: NodePath = NodePath("/root/ThemeLocalization")
const InputConfig = preload("res://InputService/InputConfig.gd")
const EventTopics = preload("res://EventBus/EventTopics.gd")

var _action_rows: Dictionary[StringName, ActionRow] = {}
var _container: VBoxContainer

class ActionRow extends RefCounted:
    var action: StringName
    var root: HBoxContainer
    var label: Label
    var binding_label: Label
    var rebind_button: Button

    func _init(row_action: StringName, row_root: HBoxContainer, row_label: Label, row_binding: Label, row_button: Button) -> void:
        action = row_action
        root = row_root
        label = row_label
        binding_label = row_binding
        rebind_button = row_button

func _ready() -> void:
    _container = _resolve_container()
    if actions.is_empty():
        actions = _default_action_list()
    _load_saved_bindings()
    _build_action_rows()
    _connect_input_service()

func _exit_tree() -> void:
    var input_service := _input_service()
    if input_service:
        if input_service.rebind_started.is_connected(_on_rebind_started):
            input_service.rebind_started.disconnect(_on_rebind_started)
        if input_service.rebind_finished.is_connected(_on_rebind_finished):
            input_service.rebind_finished.disconnect(_on_rebind_finished)
        if input_service.rebind_failed.is_connected(_on_rebind_failed):
            input_service.rebind_failed.disconnect(_on_rebind_failed)

## Build UI rows for all configured actions
## 
## Creates a UI row for each action in the actions array, including
## label, binding display, and rebind button.
func _build_action_rows() -> void:
    for child in _container.get_children():
        child.queue_free()
    _action_rows.clear()
    for action in actions:
        var row: ActionRow = _create_row(action)
        _action_rows[action] = row
        _container.add_child(row.root)
        _update_row_binding(action)

## Create a UI row for a single action
## 
## Creates a horizontal container with action label, binding display,
## and rebind button for a specific input action.
## 
## [b]action:[/b] Input action name
## 
## [b]Returns:[/b] ActionRow containing all UI elements
func _create_row(action: StringName) -> ActionRow:
    var theme_service: _ThemeService = _theme_service()
    var localization: _ThemeLocalization = _localization()
    
    var row: HBoxContainer = HBoxContainer.new()
    row.name = String(action)
    row.alignment = BoxContainer.ALIGNMENT_BEGIN
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    # Action name label
    var label: Label = Label.new()
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.text = localization.translate(StringName("%s%s" % [label_prefix, action]), _humanize_action(action)) if localization else _humanize_action(action)
    if theme_service:
        label.add_theme_font_size_override("font_size", theme_service.get_font_size(StringName("body")))
        label.add_theme_color_override("font_color", theme_service.get_color(StringName("text_primary")))
    row.add_child(label)

    # Current binding display
    var binding_label: Label = Label.new()
    binding_label.text = ""
    binding_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if theme_service:
        binding_label.add_theme_font_size_override("font_size", theme_service.get_font_size(StringName("body")))
        binding_label.add_theme_color_override("font_color", theme_service.get_color(StringName("text_muted")))
    row.add_child(binding_label)

    # Rebind button
    var button: Button = Button.new()
    button.text = _rebind_button_text(localization)
    button.pressed.connect(_on_rebind_button_pressed.bind(action))
    row.add_child(button)

    return ActionRow.new(action, row, label, binding_label, button)

## Update the binding display for an action row
## 
## Refreshes the binding label text to show current input events
## for the specified action.
## 
## [b]action:[/b] Input action to update
func _update_row_binding(action: StringName) -> void:
    if not _action_rows.has(action):
        return
        
    var events: Array = InputMap.action_get_events(action)
    var text: String = _events_to_text(events)
    _action_rows[action].binding_label.text = text

## Convert input events to human-readable text
## 
## Converts an array of InputEvent objects to a comma-separated
## string representation.
## 
## [b]events:[/b] Array of InputEvent objects
## 
## [b]Returns:[/b] Human-readable string representation
func _events_to_text(events: Array) -> String:
    if events.is_empty():
        return "(Unbound)"
        
    var parts: Array[String] = []
    for e in events:
        if e is InputEvent:
            parts.append(e.as_text())
            
    if parts.is_empty():
        return "(Unbound)"
    return ", ".join(parts)

## Handle rebind button press
## 
## Initiates the rebinding process for the specified action.
## 
## [b]action:[/b] Input action to rebind
func _on_rebind_button_pressed(action: StringName) -> void:
    var input_service: Node = _input_service()
    if input_service == null:
        return
    input_service.begin_rebind(action)

## Handle rebind start event
## 
## Updates the UI to show waiting state when rebinding begins.
## 
## [b]action:[/b] Input action being rebound
func _on_rebind_started(action: StringName) -> void:
    var localization: _ThemeLocalization = _localization()
    if _action_rows.has(action):
        _action_rows[action].binding_label.text = localization.translate(StringName("ui/rebind/waiting"), "Press input...") if localization else "Press input..."

## Handle rebind completion event
## 
## Updates the UI and persists the new binding when rebinding completes.
## 
## [b]action:[/b] Input action that was rebound
func _on_rebind_finished(action: StringName) -> void:
    _update_row_binding(action)
    _persist_binding(action)
    _publish_event(EventTopics.INPUT_REBIND_FINISHED, action, {} as Dictionary[StringName, Variant])

## Handle rebind failure event
## 
## Updates the UI and publishes failure event when rebinding fails.
## 
## [b]action:[/b] Input action that failed to rebind
## [b]reason:[/b] Reason for the failure
func _on_rebind_failed(action: StringName, reason: String) -> void:
    _update_row_binding(action)
    _publish_event(EventTopics.INPUT_REBIND_FAILED, action, {StringName("reason"): reason} as Dictionary[StringName, Variant])

## Connect to InputService rebind events
## 
## Establishes connections to InputService signals for rebind
## start, finish, and failure events.
func _connect_input_service() -> void:
    var input_service: Node = _input_service()
    if input_service == null:
        return
        
    if not input_service.rebind_started.is_connected(_on_rebind_started):
        input_service.rebind_started.connect(_on_rebind_started)
    if not input_service.rebind_finished.is_connected(_on_rebind_finished):
        input_service.rebind_finished.connect(_on_rebind_finished)
    if not input_service.rebind_failed.is_connected(_on_rebind_failed):
        input_service.rebind_failed.connect(_on_rebind_failed)

## Persist input binding to settings
## 
## Saves the current input binding for an action to the settings service.
## 
## [b]action:[/b] Input action to persist
func _persist_binding(action: StringName) -> void:
    var settings: Node = _settings_service()
    if settings == null or not settings.has_method("set_value"):
        return
        
    var key: StringName = StringName("input_bindings/%s" % action)
    var events: Array = InputMap.action_get_events(action)
    var serialized: Array = []
    for e in events:
        if e is InputEvent:
            serialized.append(_serialize_event(e))
            
    settings.set_value(key, serialized)
    if settings.has_method("save"):
        settings.save()

## Load saved input bindings from settings
## 
## Restores input bindings from the settings service for all
## configured actions.
func _load_saved_bindings() -> void:
    var settings: Node = _settings_service()
    if settings == null or not settings.has_method("get_value"):
        return
        
    for action in actions:
        var key: StringName = StringName("input_bindings/%s" % action)
        var data: Variant = settings.get_value(key, null)
        if data is Array:
            InputMap.action_erase_events(action)
            for entry in data:
                if entry is Dictionary:
                    var ev: InputEvent = _deserialize_event(entry)
                    if ev:
                        InputMap.action_add_event(action, ev)

## Serialize an InputEvent to a dictionary
## 
## Converts an InputEvent to a dictionary format suitable for
## saving to settings. Supports keyboard, mouse, and gamepad events.
## 
## [b]e:[/b] InputEvent to serialize
## 
## [b]Returns:[/b] Dictionary containing serialized event data
func _serialize_event(e: InputEvent) -> Dictionary[StringName, Variant]:
    var result: Dictionary[StringName, Variant] = {} as Dictionary[StringName, Variant]
    
    if e is InputEventKey:
        var k: InputEventKey = e
        result[StringName("type")] = StringName("key")
        result[StringName("keycode")] = k.keycode
        result[StringName("shift")] = k.shift_pressed
        result[StringName("ctrl")] = k.ctrl_pressed
        result[StringName("alt")] = k.alt_pressed
        result[StringName("meta")] = k.meta_pressed
        return result
        
    if e is InputEventMouseButton:
        var m: InputEventMouseButton = e
        result[StringName("type")] = StringName("mouse_button")
        result[StringName("button_index")] = m.button_index
        return result
        
    if e is InputEventJoypadButton:
        var j: InputEventJoypadButton = e
        result[StringName("type")] = StringName("joy_button")
        result[StringName("button_index")] = j.button_index
        return result
        
    # Fallback for unknown event types
    result[StringName("type")] = StringName("unknown")
    result[StringName("text")] = e.as_text()
    return result

## Deserialize a dictionary to an InputEvent
## 
## Converts a dictionary created by _serialize_event back to
## an InputEvent. Supports keyboard, mouse, and gamepad events.
## 
## [b]data:[/b] Dictionary containing serialized event data
## 
## [b]Returns:[/b] Reconstructed InputEvent or null if deserialization fails
func _deserialize_event(data: Dictionary) -> InputEvent:
    var entry: Dictionary[StringName, Variant] = data as Dictionary[StringName, Variant]
    var t: String = String(entry.get(StringName("type"), ""))
    
    match t:
        "key":
            var key_event: InputEventKey = InputEventKey.new()
            key_event.keycode = int(entry.get(StringName("keycode"), 0)) as Key
            key_event.shift_pressed = bool(entry.get(StringName("shift"), false))
            key_event.ctrl_pressed = bool(entry.get(StringName("ctrl"), false))
            key_event.alt_pressed = bool(entry.get(StringName("alt"), false))
            key_event.meta_pressed = bool(entry.get(StringName("meta"), false))
            return key_event
            
        "mouse_button":
            var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
            mouse_event.button_index = int(entry.get(StringName("button_index"), 0)) as MouseButton
            return mouse_event
            
        "joy_button":
            var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
            joy_event.button_index = int(entry.get(StringName("button_index"), 0)) as JoyButton
            return joy_event
            
        _:
            return null

## Get default list of actions from InputConfig
## 
## Returns all actions defined in InputConfig as StringName array.
## 
## [b]Returns:[/b] Array of action names
func _default_action_list() -> Array[StringName]:
    var result: Array[StringName] = []
    for a in InputConfig.ACTIONS:
        result.append(StringName(a))
    return result

## Resolve the container node for action rows
## 
## Gets the VBoxContainer node specified by container_path,
## or creates a fallback container if the path is invalid.
## 
## [b]Returns:[/b] VBoxContainer to use for action rows
func _resolve_container() -> VBoxContainer:
    var node: Node = get_node_or_null(container_path)
    if node == null:
        push_error("InputRebindPanel: container path %s invalid" % container_path)
        var fallback: VBoxContainer = VBoxContainer.new()
        add_child(fallback)
        return fallback
    return node as VBoxContainer

## Get the InputService singleton
## 
## [b]Returns:[/b] InputService node or null if not found
func _input_service() -> Node:
    return get_node_or_null(INPUT_SERVICE_PATH)

## Get the SettingsService singleton
## 
## [b]Returns:[/b] SettingsService node or null if not found
func _settings_service() -> Node:
    return get_node_or_null(SETTINGS_SERVICE_PATH)

## Get the ThemeService singleton
## 
## [b]Returns:[/b] ThemeService instance or null if not found
func _theme_service() -> _ThemeService:
    return get_node_or_null(THEME_SERVICE_PATH) as _ThemeService

## Get the ThemeLocalization singleton
## 
## [b]Returns:[/b] ThemeLocalization instance or null if not found
func _localization() -> _ThemeLocalization:
    return get_node_or_null(LOCALIZATION_PATH) as _ThemeLocalization

## Convert action name to human-readable text
## 
## Converts an action name like "move_left" to "Move Left".
## 
## [b]action:[/b] Action name to convert
## 
## [b]Returns:[/b] Human-readable action name
func _humanize_action(action: StringName) -> String:
    return String(action).capitalize().replace("_", " ")

## Get localized text for rebind button
## 
## [b]localization:[/b] Localization service instance
## 
## [b]Returns:[/b] Localized button text
func _rebind_button_text(localization: _ThemeLocalization) -> String:
    return localization.translate(StringName("ui/rebind/change"), "Change") if localization else "Change"

## Publish an event to EventBus
## 
## Publishes a rebind-related event to the EventBus with
## action and timestamp information.
## 
## [b]topic:[/b] Event topic to publish
## [b]action:[/b] Input action involved
## [b]extra:[/b] Additional data to include
func _publish_event(topic: StringName, action: StringName, extra: Dictionary[StringName, Variant]) -> void:
    if not Engine.has_singleton("EventBus"):
        return
        
    var payload: Dictionary[StringName, Variant] = {
        StringName("action"): action,
        StringName("timestamp_ms"): Time.get_ticks_msec()
    } as Dictionary[StringName, Variant]
    
    for key in extra.keys():
        payload[key] = extra[key]
        
    Engine.get_singleton("EventBus").call("pub", topic, payload)
