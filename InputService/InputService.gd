class_name _InputService
extends Node

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
var mirror_to_eventbus: bool = true
var emit_axis_events: bool = true
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

func _ready() -> void:
    _load_config()
    _ensure_actions_exist()
    _capture_defaults()
    _prime_axis_last_values()
    _connect_device_signals()
    _update_process_policy()
    # Register with SaveService (if available)
    if Engine.is_editor_hint() == false:
        SaveService.register_saveable(self)

func _process(_delta: float) -> void:
    if not emit_axis_events:
        return
    for axis_name in _axes.keys():
        var mapping: Dictionary = _axes[axis_name]
        if mapping == null:
            continue
        var neg := StringName(mapping.get("neg", ""))
        var pos := StringName(mapping.get("pos", ""))
        var value := Input.get_axis(neg, pos)
        var axis_sn := StringName(axis_name)
        var prev: float = _axis_last_values.get(axis_sn, 0.0)
        if not is_equal_approx(value, prev):
            _axis_last_values[axis_sn] = value
            axis_event.emit(axis_sn, value, _last_active_device_id)
            if mirror_to_eventbus:
                EventBus.pub(EventTopics.INPUT_AXIS, {"axis": axis_sn, "value": value, "device": _last_active_device_id, "ts": Time.get_ticks_msec()})

func _input(e: InputEvent) -> void:
    _update_last_device_from_event(e)
    if _rebind_action != StringName(""):
        if rebind_capture_escape_cancels and _is_escape_event(e):
            var cancelled := _rebind_action
            _rebind_action = StringName("")
            rebind_failed.emit(cancelled, "cancelled")
            if mirror_to_eventbus:
                EventBus.pub(EventTopics.INPUT_REBIND_FAILED, {"action": cancelled, "reason": "cancelled"})
            return

        if _is_bindable_event(e):
            var act := _rebind_action
            _apply_rebind(act, e)
            _rebind_action = StringName("")
            rebind_finished.emit(act)
            if mirror_to_eventbus:
                EventBus.pub(EventTopics.INPUT_REBIND_FINISHED, {"action": act})
            return

func _unhandled_input(e: InputEvent) -> void:
    _update_last_device_from_event(e)
    for a in _watched:
        if not _is_enabled(a):
            continue
        if e.is_action_pressed(a):
            _emit_action_edge(a, "pressed", e)
        if e.is_action_released(a):
            _emit_action_edge(a, "released", e)

func _emit_action_edge(action: StringName, edge: String, e: InputEvent) -> void:
    action_event.emit(action, edge, e.device, e)
    if mirror_to_eventbus:
        EventBus.pub(EventTopics.INPUT_ACTION, {"action": action, "edge": edge, "device": e.device, "ts": Time.get_ticks_msec()})

func axis_value(axis_name: StringName) -> float:
    var mapping: Dictionary = _axes.get(String(axis_name))
    if mapping == null:
        return 0.0
    return Input.get_axis(StringName(mapping.get("neg", "")), StringName(mapping.get("pos", "")))

func enable_context(ctx: StringName, on: bool) -> void:
    _contexts_enabled[StringName(ctx)] = on

func is_context_enabled(ctx: StringName) -> bool:
    return _contexts_enabled.get(StringName(ctx), true)

func begin_rebind(action: StringName) -> void:
    if not InputMap.has_action(action):
        rebind_failed.emit(action, "unknown_action")
        if mirror_to_eventbus:
            EventBus.pub(EventTopics.INPUT_REBIND_FAILED, {"action": action, "reason": "unknown_action"})
        return
    _rebind_action = StringName(action)
    rebind_started.emit(action)
    if mirror_to_eventbus:
        EventBus.pub(EventTopics.INPUT_REBIND_STARTED, {"action": action})

func cancel_rebind() -> void:
    if _rebind_action == StringName(""):
        return
    var act := _rebind_action
    _rebind_action = StringName("")
    rebind_failed.emit(act, "cancelled")
    if mirror_to_eventbus:
        EventBus.pub(EventTopics.INPUT_REBIND_FAILED, {"action": act, "reason": "cancelled"})

func save_bindings() -> Dictionary:
    var out: Dictionary = {}
    for a in _watched:
        var list: Array = []
        for ev in InputMap.action_get_events(a):
            list.append(_serialize_event(ev))
        out[a] = list
    return out

func load_bindings(bindings: Dictionary) -> void:
    for a in _watched:
        if not bindings.has(a):
            continue
        InputMap.action_erase_events(a)
        var arr: Array = bindings[a]
        for entry in arr:
            var ev: InputEvent = null
            if typeof(entry) == TYPE_DICTIONARY:
                ev = _deserialize_event(entry)
            if ev != null:
                InputMap.action_add_event(a, ev)

func reset_to_defaults() -> void:
    load_bindings(_default_bindings)

# SaveService interface
func save_data() -> Dictionary:
    return {"bindings": save_bindings()}

func load_data(data: Dictionary) -> bool:
    if data.has("bindings"):
        load_bindings(data["bindings"])
    return true

func get_save_id() -> String:
    return SAVE_ID

func get_save_priority() -> int:
    return SAVE_PRIORITY

# Helpers
func _is_enabled(action: StringName) -> bool:
    var ctx: StringName = _action_context.get(action, StringName("")) as StringName
    return ctx == StringName("") or _contexts_enabled.get(ctx, true)

func _load_config() -> void:
    _watched.clear()
    for a in InputConfig.ACTIONS:
        _watched.append(StringName(a))
    _axes = InputConfig.AXES
    _action_context.clear()
    _contexts_enabled.clear()
    for ctx in InputConfig.CONTEXTS.keys():
        var ctx_sn := StringName(ctx)
        _contexts_enabled[ctx_sn] = true
        for a in InputConfig.CONTEXTS[ctx]:
            _action_context[StringName(a)] = ctx_sn

func _ensure_actions_exist() -> void:
    for a in _watched:
        if not InputMap.has_action(a):
            InputMap.add_action(a)

func _capture_defaults() -> void:
    _default_bindings.clear()
    for a in _watched:
        var list: Array = []
        for ev in InputMap.action_get_events(a):
            list.append(_serialize_event(ev))
        _default_bindings[a] = list

func _prime_axis_last_values() -> void:
    _axis_last_values.clear()
    for axis_name in _axes.keys():
        _axis_last_values[StringName(axis_name)] = 0.0

func _connect_device_signals() -> void:
    if Input.has_signal("joy_connection_changed"):
        Input.joy_connection_changed.connect(_on_joy_connection_changed)
    # Prime existing gamepads
    for dev in Input.get_connected_joypads():
        _emit_device_changed(dev, true, "gamepad")

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
    _emit_device_changed(device_id, connected, "gamepad")

func _emit_device_changed(device_id: int, connected: bool, kind: String) -> void:
    device_changed.emit(device_id, connected, kind)
    if mirror_to_eventbus:
        EventBus.pub(EventTopics.INPUT_DEVICE_CHANGED, {"device_id": device_id, "connected": connected, "kind": kind})

func _update_last_device_from_event(e: InputEvent) -> void:
    var kind := _device_kind_from_event(e)
    if kind == "":
        return
    var device_id := e.device
    if kind != _last_active_device_kind or device_id != _last_active_device_id:
        _last_active_device_kind = kind
        _last_active_device_id = device_id
        last_active_device_changed.emit(kind, device_id)

func _device_kind_from_event(e: InputEvent) -> String:
    if e is InputEventJoypadButton or e is InputEventJoypadMotion:
        return "gamepad"
    if e is InputEventMouseButton or e is InputEventMouseMotion:
        return "mouse"
    if e is InputEventKey:
        return "keyboard"
    return ""

func _is_escape_event(e: InputEvent) -> bool:
    if not (e is InputEventKey):
        return false
    var k: InputEventKey = e
    return k.pressed and not k.echo and k.keycode == KEY_ESCAPE

func _is_bindable_event(e: InputEvent) -> bool:
    if e is InputEventKey:
        var k: InputEventKey = e
        return k.pressed and not k.echo
    if e is InputEventMouseButton:
        var m: InputEventMouseButton = e
        return m.pressed
    if e is InputEventJoypadButton:
        var j: InputEventJoypadButton = e
        return j.pressed
    # Skip motion by default in MVP
    return false

func _apply_rebind(action: StringName, e: InputEvent) -> void:
    InputMap.action_erase_events(action)
    var clone := _clone_event_for_map(e)
    if clone != null:
        InputMap.action_add_event(action, clone)

func _set_process_policy(always: bool) -> void:
    process_always = always
    _update_process_policy()

func _update_process_policy() -> void:
    process_mode = Node.PROCESS_MODE_WHEN_PAUSED if process_always else Node.PROCESS_MODE_PAUSABLE

func _serialize_event(e: InputEvent) -> Dictionary:
    if e is InputEventKey:
        var k: InputEventKey = e
        return {
            "type": "key",
            "keycode": k.keycode,
            "shift": k.shift_pressed,
            "ctrl": k.ctrl_pressed,
            "alt": k.alt_pressed,
            "meta": k.meta_pressed
        }
    if e is InputEventMouseButton:
        var m: InputEventMouseButton = e
        return {
            "type": "mouse_button",
            "button_index": m.button_index
        }
    if e is InputEventJoypadButton:
        var j: InputEventJoypadButton = e
        return {
            "type": "joy_button",
            "button_index": j.button_index
        }
    # Fallback to text for unknown
    return {"type": "text", "text": e.as_text()}

func _deserialize_event(d: Dictionary) -> InputEvent:
    var t := String(d.get("type", ""))
    match t:
        "key":
            var k := InputEventKey.new()
            k.keycode = int(d.get("keycode", 0)) as Key
            k.shift_pressed = bool(d.get("shift", false))
            k.ctrl_pressed = bool(d.get("ctrl", false))
            k.alt_pressed = bool(d.get("alt", false))
            k.meta_pressed = bool(d.get("meta", false))
            return k
        "mouse_button":
            var m := InputEventMouseButton.new()
            m.button_index = int(d.get("button_index", 0)) as MouseButton
            return m
        "joy_button":
            var j := InputEventJoypadButton.new()
            j.button_index = int(d.get("button_index", 0)) as JoyButton
            return j
        "text":
            return null
        _:
            return null

func _clone_event_for_map(e: InputEvent) -> InputEvent:
    if e is InputEventKey:
        var ksrc: InputEventKey = e
        var k := InputEventKey.new()
        k.keycode = ksrc.keycode
        k.shift_pressed = ksrc.shift_pressed
        k.ctrl_pressed = ksrc.ctrl_pressed
        k.alt_pressed = ksrc.alt_pressed
        k.meta_pressed = ksrc.meta_pressed
        return k
    if e is InputEventMouseButton:
        var msrc: InputEventMouseButton = e
        var m := InputEventMouseButton.new()
        m.button_index = msrc.button_index
        return m
    if e is InputEventJoypadButton:
        var jsrc: InputEventJoypadButton = e
        var j := InputEventJoypadButton.new()
        j.button_index = jsrc.button_index
        return j
    return null
