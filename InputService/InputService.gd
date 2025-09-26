class_name _InputService
extends Node

const InputConfig = preload("res://InputService/InputConfig.gd")

# ───────────────────────────────────────────────────────────────────────────────
# InputService (Godot 4)
# Centralized input handling for actions, axes, context gating, rebinding, and
# optional EventBus mirroring. Also persists user bindings via SaveService.
#
# Signals below let you consume input without pulling from Input directly.
# You can also subscribe to the EventBus topics in `EventTopics.gd` if you
# prefer an event-driven pattern across systems.
# ───────────────────────────────────────────────────────────────────────────────

# Action edges and axis value notifications
## Emitted when a watched action is pressed or released after UI handled input
signal action_event(action: StringName, edge: String, device: int, event: InputEvent)
## Emitted when an axis value changes (e.g., move_x)
signal axis_event(axis: StringName, value: float, device: int)

# Rebind lifecycle
## Raised when a rebind capture starts for an action
signal rebind_started(action: StringName)
## Raised when a rebind successfully captures an input
signal rebind_finished(action: StringName)
## Raised when a rebind fails (unknown action, cancelled by Esc, etc.)
signal rebind_failed(action: StringName, reason: String)

# Device tracking
## Joypad connection/disconnection and kind notified
signal device_changed(device_id: int, connected: bool, kind: String)
## Last active device kind/id (keyboard|mouse|gamepad) updates
signal last_active_device_changed(kind: String, device_id: int)

# SaveService integration
const SAVE_ID       : String = "input_bindings_v1"
const SAVE_PRIORITY : int = 20

# Configuration
var mirror_to_eventbus: bool:
    get:
        return _mirror_to_eventbus_enabled
    set(value):
        if _mirror_to_eventbus_enabled == value:
            return
        _mirror_to_eventbus_enabled = value
        _update_axis_processing()
var emit_axis_events: bool:
    get:
        return _emit_axis_events_enabled
    set(value):
        if _emit_axis_events_enabled == value:
            return
        _emit_axis_events_enabled = value
        _update_axis_processing()
var process_always: bool = false: set = _set_process_policy
var rebind_capture_escape_cancels: bool = true

# Contexts / actions / axes
var _contexts_enabled: Dictionary = {}
var _action_context: Dictionary = {}
var _axes: Dictionary = {}
var _watched: Array[StringName] = []

# Internals
var _axis_last_values: Dictionary = {}
var _rebind_action: StringName = StringName("")
var _default_bindings: Dictionary = {}
var _last_active_device_kind: String = "keyboard"
var _last_active_device_id: int = 0
var _emit_axis_events_enabled: bool = true
var _mirror_to_eventbus_enabled: bool = true

func _ready() -> void:
    _load_config()
    _ensure_actions_exist()
    _capture_defaults()
    _prime_axis_last_values()
    _connect_device_signals()
    _update_process_policy()
    _update_axis_processing()
    # Register with SaveService (if available)
    if Engine.is_editor_hint() == false:
        SaveService.register_saveable(self)

## Process axis value changes and emit events
## 
## Monitors all configured axes for value changes and emits [signal axis_event] signals
## when values change. This runs every frame to provide smooth analog input
## handling for gamepads and other analog devices.
## 
## [b]_delta:[/b] Time elapsed since last frame (unused)
func _process(_delta: float) -> void:
    if not emit_axis_events:
        return
    
    for axis_name in _axes.keys():
        var mapping: Dictionary = _axes[axis_name]
        if mapping == null:
            continue
        
        var negative_action: StringName = mapping.get("neg", "")
        var positive_action: StringName = mapping.get("pos", "")
        
        if negative_action.is_empty() or positive_action.is_empty():
            continue
        
        var current_value: float = Input.get_axis(negative_action, positive_action)
        var axis: StringName = StringName(axis_name)
        var previous_value: float = _axis_last_values.get(axis, 0.0)
        
        if not is_equal_approx(current_value, previous_value):
            _axis_last_values[axis] = current_value
            axis_event.emit(axis, current_value, _last_active_device_id)
            
            if mirror_to_eventbus:
                EventBus.pub(EventTopics.INPUT_AXIS, {
                    "axis": axis, 
                    "value": current_value, 
                    "device": _last_active_device_id, 
                    "ts": Time.get_ticks_msec()
                })

## Handle input events for rebinding operations
## 
## Processes input events when a rebinding operation is active. Handles
## escape key cancellation and captures valid input events for rebinding.
## This runs before [method _unhandled_input] to intercept rebinding input.
## 
## [b]e:[/b] The input event to process
func _input(e: InputEvent) -> void:
    _update_last_device_from_event(e)
    
    if _rebind_action == StringName(""):
        return
    
    # Handle escape key cancellation
    if rebind_capture_escape_cancels and _is_escape_event(e):
        var cancelled_action := _rebind_action
        _rebind_action = StringName("")
        rebind_failed.emit(cancelled_action, "cancelled")
        if mirror_to_eventbus:
            EventBus.pub(EventTopics.INPUT_REBIND_FAILED, {"action": cancelled_action, "reason": "cancelled"})
        return

    # Handle valid rebinding input
    if _is_bindable_event(e):
        var action_to_rebind := _rebind_action
        _apply_rebind(action_to_rebind, e)
        _rebind_action = StringName("")
        rebind_finished.emit(action_to_rebind)
        if mirror_to_eventbus:
            EventBus.pub(EventTopics.INPUT_REBIND_FINISHED, {"action": action_to_rebind})
        return

## Handle unhandled input events for action processing
## 
## Processes input events that weren't handled by UI or other systems.
## Emits [signal action_event] signals for pressed/released states of watched actions
## that are currently enabled based on their context.
## 
## [b]e:[/b] The unhandled input event to process
func _unhandled_input(e: InputEvent) -> void:
    _update_last_device_from_event(e)
    
    for action in _watched:
        if not _is_enabled(action):
            continue
        
        if e.is_action_pressed(action):
            _emit_action_edge(action, "pressed", e)
        elif e.is_action_released(action):
            _emit_action_edge(action, "released", e)

## Emit action edge events and mirror to EventBus
## 
## Emits the [signal action_event] signal and optionally mirrors the event to EventBus
## for systems that prefer event-driven input handling.
## 
## [b]action:[/b] The action that was pressed/released
## [b]edge:[/b] Either "pressed" or "released"
## [b]e:[/b] The original input event
func _emit_action_edge(action: StringName, edge: String, e: InputEvent) -> void:
    action_event.emit(action, edge, e.device, e)
    
    if mirror_to_eventbus:
        EventBus.pub(EventTopics.INPUT_ACTION, {
            "action": action, 
            "edge": edge, 
            "device": e.device, 
            "ts": Time.get_ticks_msec()
        })

## Get the current value of a virtual axis
## 
## Retrieves the current analog value for a virtual axis defined in [InputConfig.AXES].
## The axis value ranges from -1.0 to 1.0, where -1.0 represents full negative input,
## 0.0 represents no input, and 1.0 represents full positive input.
## 
## [b]axis_name:[/b] The name of the axis to query (e.g., "move_x", "move_y")
## 
## [b]Returns:[/b] The current axis value (-1.0 to 1.0), or 0.0 if axis is not found
## 
## [b]Usage:[/b]
## [codeblock]
## var horizontal_movement = InputService.axis_value("move_x")
## var vertical_movement = InputService.axis_value("move_y")
## 
## # Use for character movement
## velocity.x = horizontal_movement * speed
## velocity.y = vertical_movement * speed
## [/codeblock]
func axis_value(axis_name: StringName) -> float:
    var mapping: Dictionary = _axes.get(axis_name)
    if mapping == null:
        return 0.0
    
    var negative_action: StringName = mapping.get("neg", "")
    var positive_action: StringName = mapping.get("pos", "")
    
    if negative_action.is_empty() or positive_action.is_empty():
        return 0.0
    
    return Input.get_axis(negative_action, positive_action)

## Enable or disable an input context
## 
## Controls whether actions within a specific context are processed. When a context
## is disabled, all actions assigned to that context will be ignored during input
## processing, effectively creating input groups that can be toggled on/off.
## 
## [b]ctx:[/b] The context name to enable/disable (e.g., "gameplay", "ui")
## [b]on:[/b] true to enable the context, false to disable it
## 
## [b]Usage:[/b]
## [codeblock]
## # Disable gameplay input when showing UI
## InputService.enable_context("gameplay", false)
## 
## # Re-enable gameplay input when closing UI
## InputService.enable_context("gameplay", true)
## [/codeblock]
func enable_context(ctx: StringName, on: bool) -> void:
    _contexts_enabled[ctx] = on

## Check if an input context is currently enabled
## 
## Returns the current enabled state of a context. If the context has never been
## explicitly set, it defaults to enabled (true).
## 
## [b]ctx:[/b] The context name to check (e.g., "gameplay", "ui")
## 
## [b]Returns:[/b] true if the context is enabled, false if disabled
## 
## [b]Usage:[/b]
## [codeblock]
## if InputService.is_context_enabled("gameplay"):
##     # Process gameplay input
##     handle_movement()
##     handle_jumping()
## [/codeblock]
func is_context_enabled(ctx: StringName) -> bool:
    return _contexts_enabled.get(ctx, true)

## Begin input rebinding for a specific action
## 
## Starts the rebinding process for the specified action. The next valid input event
## (key press, mouse button, or gamepad button) will be captured and assigned to
## this action, replacing all existing bindings. The rebinding can be cancelled
## by pressing Escape (if [member rebind_capture_escape_cancels] is enabled).
## 
## [b]action:[/b] The action name to rebind (must exist in InputMap)
## 
## [b]Usage:[/b]
## [codeblock]
## # Start rebinding the jump action
## InputService.begin_rebind("jump")
## 
## # Listen for rebind events
## InputService.rebind_started.connect(_on_rebind_started)
## InputService.rebind_finished.connect(_on_rebind_finished)
## InputService.rebind_failed.connect(_on_rebind_failed)
## [/codeblock]
func begin_rebind(action: StringName) -> void:
    if not InputMap.has_action(action):
        var error_msg := "Action '%s' does not exist in InputMap" % [action]
        push_warning("InputService: " + error_msg)
        rebind_failed.emit(action, "unknown_action")
        if mirror_to_eventbus:
            EventBus.pub(EventTopics.INPUT_REBIND_FAILED, {"action": action, "reason": "unknown_action"})
        return
    
    if _rebind_action != StringName(""):
        push_warning("InputService: Rebinding already in progress for action '%s', cancelling previous rebind" % [_rebind_action])
        cancel_rebind()
    
    _rebind_action = action
    rebind_started.emit(action)
    if mirror_to_eventbus:
        EventBus.pub(EventTopics.INPUT_REBIND_STARTED, {"action": action})

## Cancel the current input rebinding operation
## 
## Cancels any active rebinding operation and emits a [signal rebind_failed] signal with
## reason "cancelled". This is useful for cleaning up when the user cancels
## the rebinding UI or when starting a new rebind operation.
## 
## [b]Usage:[/b]
## [codeblock]
## # Cancel current rebind (e.g., when closing rebind UI)
## InputService.cancel_rebind()
## [/codeblock]
func cancel_rebind() -> void:
    if _rebind_action == StringName(""):
        return
    
    var cancelled_action := _rebind_action
    _rebind_action = StringName("")
    rebind_failed.emit(cancelled_action, "cancelled")
    if mirror_to_eventbus:
        EventBus.pub(EventTopics.INPUT_REBIND_FAILED, {"action": cancelled_action, "reason": "cancelled"})

## Save current input bindings to a dictionary
## 
## Serializes all current input bindings for watched actions into a dictionary
## that can be stored or transmitted. The returned dictionary maps action names
## to arrays of serialized input events.
## 
## [b]Returns:[/b] Dictionary containing all current bindings in serialized format
## 
## [b]Usage:[/b]
## [codeblock]
## var bindings = InputService.save_bindings()
## # Save to file or send to server
## var file = FileAccess.open("user://bindings.json", FileAccess.WRITE)
## file.store_string(JSON.stringify(bindings))
## file.close()
## [/codeblock]
func save_bindings() -> Dictionary:
    var bindings: Dictionary = {}
    
    for action in _watched:
        var events: Array = []
        for event in InputMap.action_get_events(action):
            var serialized_event = _serialize_event(event)
            if not serialized_event.is_empty():
                events.append(serialized_event)
        bindings[action] = events
    
    return bindings

## Load input bindings from a dictionary
## 
## Deserializes and applies input bindings from a dictionary previously created
## by [method save_bindings]. All existing bindings for watched actions are cleared
## before applying the new bindings.
## 
## [b]bindings:[/b] Dictionary containing serialized input bindings
## 
## [b]Usage:[/b]
## [codeblock]
## # Load from file
## var file = FileAccess.open("user://bindings.json", FileAccess.READ)
## if file != null:
##     var json_string = file.get_as_text()
##     file.close()
##     var bindings = JSON.parse_string(json_string)
##     InputService.load_bindings(bindings)
## [/codeblock]
func load_bindings(bindings: Dictionary) -> void:
    if bindings == null:
        push_warning("InputService: Cannot load null bindings")
        return
    
    for action in _watched:
        if not bindings.has(action):
            continue
        
        # Clear existing bindings for this action
        InputMap.action_erase_events(action)
        
        var events: Array = bindings[action]
        if not events is Array:
            push_warning("InputService: Invalid events array for action '%s'" % [action])
            continue
        
        # Add each deserialized event
        for event_data in events:
            if typeof(event_data) != TYPE_DICTIONARY:
                push_warning("InputService: Invalid event data type for action '%s'" % [action])
                continue
            
            var event: InputEvent = _deserialize_event(event_data)
            if event != null:
                InputMap.action_add_event(action, event)
            else:
                push_warning("InputService: Failed to deserialize event for action '%s'" % [action])

## Reset all input bindings to their default values
## 
## Restores all watched actions to their original bindings as they were when
## the InputService was first initialized. This is useful for providing a
## "Reset to Defaults" option in input settings menus.
## 
## [b]Usage:[/b]
## [codeblock]
## # Reset all bindings to defaults (e.g., in settings menu)
## InputService.reset_to_defaults()
## 
## # Save the reset bindings
## SaveService.save_game("main")
## [/codeblock]
func reset_to_defaults() -> void:
    if _default_bindings.is_empty():
        push_warning("InputService: No default bindings available to reset to")
        return
    
    load_bindings(_default_bindings)

# SaveService interface

## Save input bindings data for persistence
## 
## Implements the [ISaveable] interface for SaveService integration. Returns
## a dictionary containing the current input bindings that can be saved
## to disk and restored later.
## 
## [b]Returns:[/b] Dictionary containing bindings data for saving
func save_data() -> Dictionary:
    return {"bindings": save_bindings()}

## Load input bindings data from persistence
## 
## Implements the [ISaveable] interface for SaveService integration. Loads
## input bindings from previously saved data and applies them to the
## InputMap.
## 
## [b]data:[/b] Dictionary containing saved bindings data
## 
## [b]Returns:[/b] true if loading was successful, false otherwise
func load_data(data: Dictionary) -> bool:
    if data == null:
        push_warning("InputService: Cannot load null save data")
        return false
    
    if data.has("bindings"):
        load_bindings(data["bindings"])
        return true
    
    push_warning("InputService: No bindings data found in save data")
    return false

## Get the unique save identifier for this service
## 
## Implements the [ISaveable] interface for SaveService integration.
## 
## [b]Returns:[/b] Unique string identifier for this service's save data
func get_save_id() -> String:
    return SAVE_ID

## Get the save priority for this service
## 
## Implements the [ISaveable] interface for SaveService integration.
## Higher priority values are saved/loaded first.
## 
## [b]Returns:[/b] Priority value for save/load ordering
func get_save_priority() -> int:
    return SAVE_PRIORITY

# Helpers

## Check if an action is enabled based on its context
## 
## Determines whether an action should be processed based on its assigned context.
## Actions without a context are always enabled, while actions with a context
## are only enabled if their context is enabled.
## 
## [b]action:[/b] The action to check
## 
## [b]Returns:[/b] true if the action should be processed, false otherwise
func _is_enabled(action: StringName) -> bool:
    var context: StringName = _action_context.get(action, StringName(""))
    return context.is_empty() or _contexts_enabled.get(context, true)

## Load configuration from InputConfig
## 
## Initializes the service with actions, contexts, and axes defined in [InputConfig].
## This is called during [method _ready] to set up the input system based on the
## project's configuration.
func _load_config() -> void:
    # Load watched actions
    _watched.clear()
    for action_name in InputConfig.ACTIONS:
        _watched.append(StringName(action_name))
    
    # Load axis mappings
    _axes = InputConfig.AXES.duplicate()
    
    # Load context mappings
    _action_context.clear()
    _contexts_enabled.clear()
    
    for context_name in InputConfig.CONTEXTS.keys():
        var context: StringName = StringName(context_name)
        _contexts_enabled[context] = true
        
        for action_name in InputConfig.CONTEXTS[context_name]:
            _action_context[StringName(action_name)] = context

## Ensure all watched actions exist in InputMap
## 
## Creates any missing actions in the InputMap to prevent runtime errors.
## This is called during initialization to ensure all configured actions
## are available for use.
func _ensure_actions_exist() -> void:
    for action in _watched:
        if not InputMap.has_action(action):
            InputMap.add_action(action)

## Capture default bindings for reset functionality
## 
## Stores the original bindings for all watched actions so they can be
## restored later via reset_to_defaults(). This is called during
## initialization after actions are created.
func _capture_defaults() -> void:
    _default_bindings.clear()
    
    for action in _watched:
        var events: Array = []
        for event in InputMap.action_get_events(action):
            var serialized_event = _serialize_event(event)
            if not serialized_event.is_empty():
                events.append(serialized_event)
        _default_bindings[action] = events

## Initialize axis value tracking
## 
## Sets up the axis value tracking dictionary with initial values of 0.0
## for all configured axes. This prevents unnecessary axis events on startup.
func _prime_axis_last_values() -> void:
    _axis_last_values.clear()
    for axis_name in _axes.keys():
        _axis_last_values[StringName(axis_name)] = 0.0

## Connect to device change signals
## 
## Sets up signal connections for gamepad connection/disconnection events
## and primes the system with currently connected gamepads.
func _connect_device_signals() -> void:
    if Input.has_signal("joy_connection_changed"):
        Input.joy_connection_changed.connect(_on_joy_connection_changed)
    
    # Prime existing gamepads
    for device_id in Input.get_connected_joypads():
        _emit_device_changed(device_id, true, "gamepad")

## Handle gamepad connection changes
## 
## Called when a gamepad is connected or disconnected. Emits [signal device_changed]
## signals and optionally mirrors to EventBus.
## 
## [b]device_id:[/b] The ID of the gamepad that changed
## [b]connected:[/b] true if connected, false if disconnected
func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
    _emit_device_changed(device_id, connected, "gamepad")

## Emit device change events
## 
## Emits [signal device_changed] signals and optionally mirrors to EventBus when
## input devices are connected or disconnected.
## 
## [b]device_id:[/b] The ID of the device that changed
## [b]connected:[/b] true if connected, false if disconnected
## [b]kind:[/b] The type of device ("gamepad", "keyboard", "mouse")
func _emit_device_changed(device_id: int, connected: bool, kind: String) -> void:
    device_changed.emit(device_id, connected, kind)
    
    if mirror_to_eventbus:
        EventBus.pub(EventTopics.INPUT_DEVICE_CHANGED, {
            "device_id": device_id, 
            "connected": connected, 
            "kind": kind
        })

## Update the last active device based on input event
## 
## Tracks the most recently used input device type and ID for accurate
## device reporting in action and axis events.
## 
## [b]e:[/b] The input event to analyze
func _update_last_device_from_event(e: InputEvent) -> void:
    var device_kind: String = _device_kind_from_event(e)
    if device_kind.is_empty():
        return
    
    var device_id: int = e.device
    
    if device_kind != _last_active_device_kind or device_id != _last_active_device_id:
        _last_active_device_kind = device_kind
        _last_active_device_id = device_id
        last_active_device_changed.emit(device_kind, device_id)

## Determine device type from input event
## 
## Analyzes an input event to determine what type of device generated it.
## 
## [b]e:[/b] The input event to analyze
## 
## [b]Returns:[/b] Device type string ("gamepad", "mouse", "keyboard") or empty string
func _device_kind_from_event(e: InputEvent) -> String:
    if e is InputEventJoypadButton or e is InputEventJoypadMotion:
        return "gamepad"
    elif e is InputEventMouseButton or e is InputEventMouseMotion:
        return "mouse"
    elif e is InputEventKey:
        return "keyboard"
    else:
        return ""

## Check if input event is the escape key
## 
## Determines if the input event represents a pressed escape key (not echo).
## Used for cancelling rebinding operations.
## 
## [b]e:[/b] The input event to check
## 
## [b]Returns:[/b] true if the event is a pressed escape key
func _is_escape_event(e: InputEvent) -> bool:
    if not (e is InputEventKey):
        return false
    
    var key_event: InputEventKey = e
    return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE

## Check if input event can be used for rebinding
## 
## Determines if an input event is suitable for use as a binding.
## Only accepts pressed events (not released or echo) for keys, mouse buttons,
## and gamepad buttons. Motion events are excluded.
## 
## [b]e:[/b] The input event to check
## 
## [b]Returns:[/b] true if the event can be used for rebinding
func _is_bindable_event(e: InputEvent) -> bool:
    if e is InputEventKey:
        var key_event: InputEventKey = e
        return key_event.pressed and not key_event.echo
    elif e is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = e
        return mouse_event.pressed
    elif e is InputEventJoypadButton:
        var joy_event: InputEventJoypadButton = e
        return joy_event.pressed
    else:
        # Skip motion events and other types
        return false

## Apply a rebinding to an action
## 
## Clears existing bindings for the action and adds the new event as a binding.
## 
## [b]action:[/b] The action to rebind
## [b]e:[/b] The input event to use as the new binding
func _apply_rebind(action: StringName, e: InputEvent) -> void:
    InputMap.action_erase_events(action)
    var cloned_event: InputEvent = _clone_event_for_map(e)
    if cloned_event != null:
        InputMap.action_add_event(action, cloned_event)

## Set the process policy for the service
## 
## Controls whether the service processes input when the game is paused.
## 
## [b]always:[/b] true to process even when paused, false to pause with the game
func _set_process_policy(always: bool) -> void:
    process_always = always
    _update_process_policy()
    _update_axis_processing()

## Update the node's process mode based on current policy
## 
## Applies the current process_always setting to the node's process_mode.
func _update_process_policy() -> void:
    process_mode = Node.PROCESS_MODE_WHEN_PAUSED if process_always else Node.PROCESS_MODE_PAUSABLE

func _update_axis_processing() -> void:
    var needs_process: bool = emit_axis_events or mirror_to_eventbus
    set_process(needs_process)

## Serialize an input event to a dictionary
## 
## Converts an InputEvent to a dictionary format suitable for saving/loading.
## Supports keyboard, mouse button, and gamepad button events.
## 
## [b]e:[/b] The input event to serialize
## 
## [b]Returns:[/b] Dictionary containing serialized event data, or empty dictionary if unsupported
func _serialize_event(e: InputEvent) -> Dictionary:
    if e is InputEventKey:
        var key_event: InputEventKey = e
        return {
            "type": "key",
            "keycode": key_event.keycode,
            "shift": key_event.shift_pressed,
            "ctrl": key_event.ctrl_pressed,
            "alt": key_event.alt_pressed,
            "meta": key_event.meta_pressed
        }
    elif e is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = e
        return {
            "type": "mouse_button",
            "button_index": mouse_event.button_index
        }
    elif e is InputEventJoypadButton:
        var joy_event: InputEventJoypadButton = e
        return {
            "type": "joy_button",
            "button_index": joy_event.button_index
        }
    else:
        # Unsupported event type
        return {}

## Deserialize a dictionary to an input event
## 
## Converts a dictionary created by [method _serialize_event] back to an InputEvent.
## Supports keyboard, mouse button, and gamepad button events.
## 
## [b]d:[/b] Dictionary containing serialized event data
## 
## [b]Returns:[/b] Reconstructed InputEvent, or null if deserialization failed
func _deserialize_event(d: Dictionary) -> InputEvent:
    if d == null:
        return null
    
    var event_type: String = String(d.get("type", ""))
    
    match event_type:
        "key":
            var key_event := InputEventKey.new()
            key_event.keycode = int(d.get("keycode", 0)) as Key
            key_event.shift_pressed = bool(d.get("shift", false))
            key_event.ctrl_pressed = bool(d.get("ctrl", false))
            key_event.alt_pressed = bool(d.get("alt", false))
            key_event.meta_pressed = bool(d.get("meta", false))
            return key_event
        "mouse_button":
            var mouse_event := InputEventMouseButton.new()
            mouse_event.button_index = int(d.get("button_index", 0)) as MouseButton
            return mouse_event
        "joy_button":
            var joy_event := InputEventJoypadButton.new()
            joy_event.button_index = int(d.get("button_index", 0)) as JoyButton
            return joy_event
        _:
            # Unknown or unsupported event type
            return null

## Clone an input event for use in InputMap
## 
## Creates a clean copy of an input event suitable for adding to InputMap.
## Only copies the essential properties needed for the binding.
## 
## [b]e:[/b] The input event to clone
## 
## [b]Returns:[/b] Cloned InputEvent, or null if unsupported
func _clone_event_for_map(e: InputEvent) -> InputEvent:
    if e is InputEventKey:
        var source_key: InputEventKey = e
        var cloned_key := InputEventKey.new()
        cloned_key.keycode = source_key.keycode
        cloned_key.shift_pressed = source_key.shift_pressed
        cloned_key.ctrl_pressed = source_key.ctrl_pressed
        cloned_key.alt_pressed = source_key.alt_pressed
        cloned_key.meta_pressed = source_key.meta_pressed
        return cloned_key
    elif e is InputEventMouseButton:
        var source_mouse: InputEventMouseButton = e
        var cloned_mouse := InputEventMouseButton.new()
        cloned_mouse.button_index = source_mouse.button_index
        return cloned_mouse
    elif e is InputEventJoypadButton:
        var source_joy: InputEventJoypadButton = e
        var cloned_joy := InputEventJoypadButton.new()
        cloned_joy.button_index = source_joy.button_index
        return cloned_joy
    else:
        # Unsupported event type
        return null
