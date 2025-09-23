extends Control
class_name PerformanceOverlay

## Performance overlay showing FPS, frame time, memory, and custom metrics.

@export var enabled: bool = false
@export var position_top_left: bool = true
@export var text_color: Color = Color.WHITE
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.8)
@export var font_size: int = 14

var _metrics: Dictionary = {}
var _frame_count: int = 0
var _fps: float = 0.0
var _frame_time: float = 0.0

signal metric_updated(metric_name: String, value: Variant)

func _ready() -> void:
    visible = enabled
    _setup_ui()

    # Connect to performance monitoring
    if Engine.has_singleton("Performance"):
        _connect_performance_monitor()

func _setup_ui() -> void:
    # Create main panel
    var panel = Panel.new()
    panel.name = "PerformancePanel"
    panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
    panel.get_theme_stylebox("panel").bg_color = background_color
    add_child(panel)

    # Create label for metrics
    var label = Label.new()
    label.name = "MetricsLabel"
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", text_color)
    panel.add_child(label)

    # Position the overlay
    if position_top_left:
        anchors_preset = PRESET_TOP_LEFT
        panel.custom_minimum_size = Vector2(200, 100)
    else:
        anchors_preset = PRESET_TOP_RIGHT
        panel.custom_minimum_size = Vector2(200, 100)

func _connect_performance_monitor() -> void:
    # Monitor built-in performance metrics
    _update_metric("fps", Performance.get_monitor(Performance.TIME_FPS))
    _update_metric("frame_time", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)

    # Memory monitoring
    _update_metric("memory_static", Performance.get_monitor(Performance.MEMORY_STATIC))
    _update_metric("memory_total", Performance.get_monitor(Performance.MEMORY_STATIC))

    # Object counts
    _update_metric("objects", Performance.get_monitor(Performance.OBJECT_COUNT))
    _update_metric("nodes", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

func _process(delta: float) -> void:
    if not enabled or not visible:
        return

    _frame_count += 1
    _frame_time = delta * 1000.0  # Convert to milliseconds

    # Update FPS every 10 frames
    if _frame_count % 10 == 0:
        _fps = 1.0 / delta
        _update_metric("fps", _fps)
        _update_metric("frame_time", _frame_time)

        # Update memory metrics less frequently
        if _frame_count % 60 == 0:
            _connect_performance_monitor()

    _update_display()

func _update_metric(metric_name: String, value: Variant) -> void:
    _metrics[metric_name] = value
    metric_updated.emit(metric_name, value)

func _update_display() -> void:
    var label = get_node_or_null("PerformancePanel/MetricsLabel") as Label
    if not label:
        return

    var text = "Performance Metrics\n"
    text += "FPS: %.1f\n" % _metrics.get("fps", 0.0)
    text += "Frame Time: %.2f ms\n" % _metrics.get("frame_time", 0.0)
    text += "Memory: %.1f MB\n" % (_metrics.get("memory_total", 0) / (1024.0 * 1024.0))
    text += "Objects: %d\n" % _metrics.get("objects", 0)
    text += "Nodes: %d\n" % _metrics.get("nodes", 0)

    # Add custom metrics
    for metric_name in _metrics:
        if not ["fps", "frame_time", "memory_static", "memory_dynamic", "memory_total", "objects", "nodes"].has(metric_name):
            var value = _metrics[metric_name]
            text += "%s: %s\n" % [metric_name.capitalize(), str(value)]

    label.text = text

func add_custom_metric(metric_name: String, value: Variant) -> void:
    _update_metric(metric_name, value)

func remove_custom_metric(metric_name: String) -> void:
    _metrics.erase(metric_name)

func toggle_visibility() -> void:
    visible = not visible

func set_enabled(enable: bool) -> void:
    enabled = enable
    visible = enabled

func is_enabled() -> bool:
    return enabled
