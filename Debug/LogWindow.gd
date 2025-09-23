extends Control
class_name LogWindow

## Log window subscribing to EventBus diagnostics topics.

@export var enabled: bool = false
@export var max_lines: int = 100
@export var text_color: Color = Color.WHITE
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.9)
@export var font_size: int = 12
@export var show_timestamps: bool = true
@export var auto_scroll: bool = true

var _log_lines: Array[String] = []
var _event_filters: Array[String] = []
var _is_paused: bool = false

signal log_message_added(message: String, level: String)
signal log_cleared()

func _ready() -> void:
    visible = enabled
    _setup_ui()
    _connect_event_bus()

func _setup_ui() -> void:
    # Create main panel
    var panel = Panel.new()
    panel.name = "LogPanel"
    panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
    panel.get_theme_stylebox("panel").bg_color = background_color
    add_child(panel)

    # Create scroll container
    var scroll = ScrollContainer.new()
    scroll.name = "LogScroll"
    scroll.size_flags_vertical = SIZE_EXPAND_FILL
    panel.add_child(scroll)

    # Create text container
    var text_container = VBoxContainer.new()
    text_container.name = "LogContainer"
    scroll.add_child(text_container)

    # Create log text
    var log_text = RichTextLabel.new()
    log_text.name = "LogText"
    log_text.size_flags_vertical = SIZE_EXPAND_FILL
    log_text.scroll_following = auto_scroll
    log_text.bbcode_enabled = true
    log_text.add_theme_font_size_override("normal_font_size", font_size)
    log_text.add_theme_color_override("default_color", text_color)
    text_container.add_child(log_text)

    # Create control buttons
    var button_container = HBoxContainer.new()
    button_container.name = "ButtonContainer"
    panel.add_child(button_container)

    var clear_button = Button.new()
    clear_button.text = "Clear"
    clear_button.pressed.connect(_clear_log)
    button_container.add_child(clear_button)

    var pause_button = Button.new()
    pause_button.text = "Pause"
    pause_button.pressed.connect(_toggle_pause)
    button_container.add_child(pause_button)

    var filter_button = Button.new()
    filter_button.text = "Filter"
    filter_button.pressed.connect(_show_filter_dialog)
    button_container.add_child(filter_button)

    # Position and size
    anchors_preset = PRESET_BOTTOM_LEFT
    panel.custom_minimum_size = Vector2(600, 200)

func _connect_event_bus() -> void:
    if not Engine.has_singleton("EventBus"):
        return

    var event_bus = Engine.get_singleton("EventBus")

    # Subscribe to all events for logging
    event_bus.call("sub_all", _on_event_logged)

    # Listen for specific debug events
    event_bus.call("sub", &"debug/log", _on_debug_log)
    event_bus.call("sub", &"debug/warning", _on_debug_warning)
    event_bus.call("sub", &"debug/error", _on_debug_error)

func _on_event_logged(envelope: Dictionary) -> void:
    if _is_paused:
        return

    var topic: String = envelope.get("topic", "unknown")
    var payload: Dictionary = envelope.get("payload", {})

    # Apply filters
    if not _event_filters.is_empty():
        var should_log = false
        for filter in _event_filters:
            if topic.contains(filter):
                should_log = true
                break
        if not should_log:
            return

    _add_log_entry("EVENT", "[%s] %s: %s" % [topic, envelope.get("timestamp_ms", 0), str(payload)])

func _on_debug_log(payload: Dictionary) -> void:
    _add_log_entry("LOG", payload.get("message", ""))

func _on_debug_warning(payload: Dictionary) -> void:
    _add_log_entry("WARNING", payload.get("message", ""))

func _on_debug_error(payload: Dictionary) -> void:
    _add_log_entry("ERROR", payload.get("message", ""))

func _add_log_entry(level: String, message: String) -> void:
    var timestamp = ""
    if show_timestamps:
        var time_dict = Time.get_time_dict_from_system()
        timestamp = "[%02d:%02d:%02d] " % [time_dict.hour, time_dict.minute, time_dict.second]

    var formatted_message = "%s[%s] %s" % [timestamp, level, message]

    _log_lines.append(formatted_message)
    log_message_added.emit(formatted_message, level)

    # Limit lines
    if _log_lines.size() > max_lines:
        _log_lines.remove_at(0)

    _update_display()

func _update_display() -> void:
    var log_text = get_node_or_null("LogPanel/LogScroll/LogContainer/LogText") as RichTextLabel
    if not log_text:
        return

    log_text.clear()

    for line in _log_lines:
        var bbcode_line = line
        match line.split("]")[1].strip_edges():
            "ERROR":
                bbcode_line = "[color=red]" + line + "[/color]"
            "WARNING":
                bbcode_line = "[color=yellow]" + line + "[/color]"
            "LOG":
                bbcode_line = "[color=gray]" + line + "[/color]"

        log_text.append_text(bbcode_line + "\n")

func _clear_log() -> void:
    _log_lines.clear()
    log_cleared.emit()
    _update_display()

func _toggle_pause() -> void:
    _is_paused = not _is_paused
    var pause_button = get_node_or_null("LogPanel/ButtonContainer/Pause") as Button
    if pause_button:
        pause_button.text = "Resume" if _is_paused else "Pause"

func _show_filter_dialog() -> void:
    # TODO: Implement filter dialog UI
    pass

func add_filter(filter: String) -> void:
    if not _event_filters.has(filter):
        _event_filters.append(filter)

func remove_filter(filter: String) -> void:
    _event_filters.erase(filter)

func clear_filters() -> void:
    _event_filters.clear()

func set_log_level(_level: String) -> void:
    # Could implement log level filtering
    pass

func toggle_visibility() -> void:
    visible = not visible

func set_enabled(enable: bool) -> void:
    enabled = enable
    visible = enabled

func is_enabled() -> bool:
    return enabled

func get_log_line_count() -> int:
    return _log_lines.size()

func get_recent_lines(count: int) -> Array[String]:
    var recent: Array[String] = []
    var start_index = max(0, _log_lines.size() - count)
    for i in range(start_index, _log_lines.size()):
        recent.append(_log_lines[i])
    return recent
