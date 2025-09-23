extends Node
class_name CrashReporter

## Optional crash reporter stub hooking into Godot crash signals.

@export var enabled: bool = false
@export var log_crashes_to_file: bool = true
@export var max_crash_logs: int = 10
@export var include_system_info: bool = true
@export var include_scene_info: bool = true
@export var include_performance_metrics: bool = true

var _crash_log_path: String = "user://crash_logs"
var _crash_count: int = 0
var _last_crash_data: Dictionary = {}

signal crash_detected(crash_data: Dictionary)
signal crash_log_saved(log_path: String)

func _ready() -> void:
    if not enabled:
        return

    _setup_crash_directory()
    _connect_crash_signals()

func _setup_crash_directory() -> void:
    if not log_crashes_to_file:
        return

    var dir = DirAccess.open("user://")
    if not dir.dir_exists("crash_logs"):
        dir.make_dir("crash_logs")

func _connect_crash_signals() -> void:
    # Connect to Godot's crash handling signals
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)

    # These would be connected to actual Godot crash signals if available
    # For now, we'll simulate crash detection through error signals
    get_tree().set_meta("crash_handler", self)

func _on_node_added(node: Node) -> void:
    # Monitor for crash-related nodes or error conditions
    if node.has_signal("crashed") or node.has_signal("failed"):
        node.crashed.connect(_handle_crash)
        node.failed.connect(_handle_crash)

func _on_node_removed(_node: Node) -> void:
    # Clean up connections
    pass

func _handle_crash(crash_source: Node = null) -> void:
    _crash_count += 1

    var crash_data = _collect_crash_data(crash_source)
    _last_crash_data = crash_data

    crash_detected.emit(crash_data)

    if log_crashes_to_file:
        _save_crash_log(crash_data)

    # Emit through EventBus for analytics
    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"debug/crash_detected", {
            "crash_id": crash_data.get("crash_id", "unknown"),
            "timestamp": crash_data.get("timestamp", 0),
            "severity": crash_data.get("severity", "unknown"),
            "location": crash_data.get("location", "unknown")
        })

func _collect_crash_data(crash_source: Node = null) -> Dictionary:
    var crash_data = {
        "crash_id": _generate_crash_id(),
        "timestamp": Time.get_ticks_msec(),
        "godot_version": Engine.get_version_info().get("string", "unknown"),
        "platform": OS.get_name(),
        "severity": _determine_severity(crash_source),
        "location": _get_crash_location(crash_source),
        "stack_trace": _get_stack_trace(),
        "scene_info": {},
        "performance_metrics": {},
        "system_info": {},
        "custom_data": {}
    }

    if include_scene_info:
        crash_data.scene_info = _collect_scene_info()

    if include_performance_metrics:
        crash_data.performance_metrics = _collect_performance_metrics()

    if include_system_info:
        crash_data.system_info = _collect_system_info()

    return crash_data

func _generate_crash_id() -> String:
    var timestamp = Time.get_time_dict_from_system()
    return "crash_%04d%02d%02d_%02d%02d%02d_%03d" % [
        timestamp.year, timestamp.month, timestamp.day,
        timestamp.hour, timestamp.minute, timestamp.second,
        randi() % 1000
    ]

func _determine_severity(crash_source: Node) -> String:
    if crash_source == null:
        return "low"

    # This would analyze the crash source to determine severity
    return "medium"  # Default

func _get_crash_location(crash_source: Node) -> String:
    if crash_source:
        return crash_source.scene_file_path + "::" + crash_source.name
    return get_tree().current_scene.scene_file_path if get_tree().current_scene else "unknown"

func _get_stack_trace() -> String:
    # In a real implementation, this would capture the call stack
    # For now, return a placeholder
    return "Stack trace capture not implemented in base system"

func _collect_scene_info() -> Dictionary:
    var scene = get_tree().current_scene
    if not scene:
        return {"current_scene": "none"}

    return {
        "current_scene": scene.name,
        "scene_path": scene.scene_file_path,
        "node_count": _count_nodes(scene),
        "script_count": _count_scripts(scene)
    }

func _collect_performance_metrics() -> Dictionary:
    return {
        "fps": Performance.get_monitor(Performance.TIME_FPS),
        "frame_time": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
        "memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
        "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
        "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
    }

func _collect_system_info() -> Dictionary:
    return {
        "os_name": OS.get_name(),
        "os_version": OS.get_version(),
        "cpu_name": OS.get_processor_name(),
        "cpu_count": OS.get_processor_count(),
        "memory_mb": OS.get_memory_info().get("physical", 0) / (1024 * 1024),
        "video_adapter": OS.get_video_adapter_driver_info()[0] if OS.get_video_adapter_driver_info().size() > 0 else "unknown"
    }

func _count_nodes(node: Node, count: int = 0) -> int:
    count += 1
    for child in node.get_children():
        count = _count_nodes(child, count)
    return count

func _count_scripts(node: Node, count: int = 0) -> int:
    if node.get_script() != null:
        count += 1
    for child in node.get_children():
        count = _count_scripts(child, count)
    return count

func _save_crash_log(crash_data: Dictionary) -> void:
    if not log_crashes_to_file:
        return

    var timestamp = Time.get_time_dict_from_system()
    var filename = "crash_%04d%02d%02d_%02d%02d%02d.json" % [
        timestamp.year, timestamp.month, timestamp.day,
        timestamp.hour, timestamp.minute, timestamp.second
    ]

    var file_path = _crash_log_path + "/" + filename

    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(crash_data, "  "))
        file.close()
        crash_log_saved.emit(file_path)

        # Clean up old crash logs
        _cleanup_old_crash_logs()
    else:
        push_error("Failed to save crash log: " + file_path)

func _cleanup_old_crash_logs() -> void:
    var dir = DirAccess.open(_crash_log_path)
    if not dir:
        return

    var crash_files: Array[String] = []
    dir.list_dir_begin()

    var file_name = dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.begins_with("crash_") and file_name.ends_with(".json"):
            crash_files.append(file_name)
        file_name = dir.get_next()

    dir.list_dir_end()

    # Sort by modification time (newest first)
    crash_files.sort()
    crash_files.reverse()

    # Remove excess files
    while crash_files.size() > max_crash_logs:
        var file_to_remove = crash_files.pop_back()
        dir.remove(file_to_remove)

func set_enabled(enable: bool) -> void:
    enabled = enable

func is_enabled() -> bool:
    return enabled

func get_crash_count() -> int:
    return _crash_count

func get_last_crash_data() -> Dictionary:
    return _last_crash_data.duplicate(true)

func get_crash_log_path() -> String:
    return _crash_log_path

func set_crash_log_path(path: String) -> void:
    _crash_log_path = path
    _setup_crash_directory()

func get_crash_logs_list() -> Array[String]:
    if not DirAccess.dir_exists_absolute(_crash_log_path):
        return []

    var dir = DirAccess.open(_crash_log_path)
    var crash_files: Array[String] = []

    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()

        while file_name != "":
            if not dir.current_is_dir() and file_name.begins_with("crash_") and file_name.ends_with(".json"):
                crash_files.append(_crash_log_path + "/" + file_name)
            file_name = dir.get_next()

        dir.list_dir_end()

    return crash_files

func load_crash_log(file_path: String) -> Dictionary:
    if not FileAccess.file_exists(file_path):
        return {}

    var file = FileAccess.open(file_path, FileAccess.READ)
    if file:
        var content = file.get_as_text()
        file.close()

        var json = JSON.new()
        var result = json.parse(content)
        if result == OK:
            return json.get_data()
        else:
            push_error("Failed to parse crash log: " + file_path)
            return {}

    return {}

func clear_crash_logs() -> void:
    var crash_files = get_crash_logs_list()
    for file_path in crash_files:
        var dir = DirAccess.open(_crash_log_path)
        if dir:
            dir.remove(file_path.get_file())

func simulate_crash() -> void:
    # For testing purposes - simulates a crash condition
    _handle_crash(self)

func get_crash_statistics() -> Dictionary:
    return {
        "total_crashes": _crash_count,
        "crash_log_count": get_crash_logs_list().size(),
        "last_crash_time": _last_crash_data.get("timestamp", 0),
        "system_info": _collect_system_info() if include_system_info else {}
    }
