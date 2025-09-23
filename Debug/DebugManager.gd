extends Node
class_name DebugManager

## Central manager for debug tools with InputService integration.

@export var performance_overlay_scene: PackedScene
@export var log_window_scene: PackedScene
@export var debug_console_scene: PackedScene
@export var event_bus_inspector_scene: PackedScene

var _performance_overlay: Control
var _log_window: Control
var _debug_console: Control
var _event_bus_inspector: Control

var _debug_tools_enabled: bool = false
var _security_token: String = ""

signal debug_tools_toggled(enabled: bool)
signal debug_command_executed(command: String, result: String)

func _ready() -> void:
    _setup_input_actions()
    _check_debug_environment()

func _setup_input_actions() -> void:
    if not Engine.has_singleton("InputService"):
        return

    var input_service = Engine.get_singleton("InputService")

    # Toggle performance overlay (F1)
    input_service.call("register_action", "debug_toggle_performance", KEY_F1)

    # Toggle log window (F2)
    input_service.call("register_action", "debug_toggle_log", KEY_F2)

    # Toggle debug console (F3)
    input_service.call("register_action", "debug_toggle_console", KEY_F3)

    # Toggle EventBus inspector (F4)
    input_service.call("register_action", "debug_toggle_inspector", KEY_F4)

    # Quick screenshot (F12)
    input_service.call("register_action", "debug_screenshot", KEY_F12)

func _check_debug_environment() -> void:
    # Check if running in editor or with debug flags
    if Engine.is_editor_hint():
        _debug_tools_enabled = true
        _enable_debug_tools()
    elif OS.has_feature("debug"):
        _debug_tools_enabled = true
        _enable_debug_tools()
    else:
        _debug_tools_enabled = false
        _disable_debug_tools()

func _enable_debug_tools() -> void:
    if not _debug_tools_enabled:
        return

    # Instance debug tools
    if performance_overlay_scene and not _performance_overlay:
        _performance_overlay = performance_overlay_scene.instantiate()
        get_tree().root.add_child(_performance_overlay)

    if log_window_scene and not _log_window:
        _log_window = log_window_scene.instantiate()
        get_tree().root.add_child(_log_window)

    if debug_console_scene and not _debug_console:
        _debug_console = debug_console_scene.instantiate()
        get_tree().root.add_child(_debug_console)

    if event_bus_inspector_scene and not _event_bus_inspector:
        _event_bus_inspector = event_bus_inspector_scene.instantiate()
        get_tree().root.add_child(_event_bus_inspector)

func _disable_debug_tools() -> void:
    if _performance_overlay:
        _performance_overlay.queue_free()
        _performance_overlay = null

    if _log_window:
        _log_window.queue_free()
        _log_window = null

    if _debug_console:
        _debug_console.queue_free()
        _debug_console = null

    if _event_bus_inspector:
        _event_bus_inspector.queue_free()
        _event_bus_inspector = null

func _input(event: InputEvent) -> void:
    if not _debug_tools_enabled:
        return

    if event.is_action_pressed("debug_toggle_performance"):
        _toggle_performance_overlay()

    elif event.is_action_pressed("debug_toggle_log"):
        _toggle_log_window()

    elif event.is_action_pressed("debug_toggle_console"):
        _toggle_debug_console()

    elif event.is_action_pressed("debug_toggle_inspector"):
        _toggle_event_bus_inspector()

    elif event.is_action_pressed("debug_screenshot"):
        _take_screenshot()

func _toggle_performance_overlay() -> void:
    if _performance_overlay:
        _performance_overlay.toggle_visibility()
        debug_tools_toggled.emit(_performance_overlay.visible)

func _toggle_log_window() -> void:
    if _log_window:
        _log_window.toggle_visibility()
        debug_tools_toggled.emit(_log_window.visible)

func _toggle_debug_console() -> void:
    if _debug_console:
        _debug_console.toggle_visibility()
        debug_tools_toggled.emit(_debug_console.visible)

func _toggle_event_bus_inspector() -> void:
    if _event_bus_inspector:
        _event_bus_inspector.toggle_visibility()
        debug_tools_toggled.emit(_event_bus_inspector.visible)

func _take_screenshot() -> void:
    var timestamp = Time.get_time_dict_from_system()
    var filename = "screenshot_%04d%02d%02d_%02d%02d%02d.png" % [
        timestamp.year, timestamp.month, timestamp.day,
        timestamp.hour, timestamp.minute, timestamp.second
    ]

    var image = get_viewport().get_texture().get_image()
    var result = image.save_png(filename)

    if result == OK:
        print("Screenshot saved: ", filename)
        debug_command_executed.emit("screenshot", "Saved: " + filename)
    else:
        print("Failed to save screenshot")
        debug_command_executed.emit("screenshot", "Failed to save screenshot")

func set_security_token(token: String) -> void:
    _security_token = token

func get_security_token() -> String:
    return _security_token

func is_debug_enabled() -> bool:
    return _debug_tools_enabled

func enable_debug_tools() -> void:
    _debug_tools_enabled = true
    _enable_debug_tools()

func disable_debug_tools() -> void:
    _debug_tools_enabled = false
    _disable_debug_tools()

func add_custom_metric(metric_name: String, value: Variant) -> void:
    if _performance_overlay and _performance_overlay.has_method("add_custom_metric"):
        _performance_overlay.call("add_custom_metric", metric_name, value)

func remove_custom_metric(metric_name: String) -> void:
    if _performance_overlay and _performance_overlay.has_method("remove_custom_metric"):
        _performance_overlay.call("remove_custom_metric", metric_name)

func log_debug_message(message: String, level: String = "LOG") -> void:
    if _log_window and _log_window.has_method("log_debug_message"):
        _log_window.call("log_debug_message", message, level)

func execute_console_command(command: String) -> String:
    if _debug_console and _debug_console.has_method("execute_command"):
        return _debug_console.call("execute_command", command)
    return "Console not available"

func refresh_event_bus_inspector() -> void:
    if _event_bus_inspector and _event_bus_inspector.has_method("refresh"):
        _event_bus_inspector.call("refresh")
