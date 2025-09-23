extends Control
class_name EventBusInspector

## Inspector tool visualizing EventBus topics and payloads.

@export var enabled: bool = false
@export var text_color: Color = Color.WHITE
@export var background_color: Color = Color(0.15, 0.15, 0.2, 0.9)
@export var font_size: int = 12
@export var max_events_per_topic: int = 10
@export var auto_refresh_interval: float = 1.0

var _event_history: Dictionary = {}  # topic -> array of events
var _topic_filters: Array[String] = []
var _is_paused: bool = false
var _refresh_timer: float = 0.0
var _selected_topic: String = ""
var _event_bus_available: bool = false

signal topic_selected(topic: String)
signal event_selected(event_data: Dictionary)
signal inspector_refreshed()

func _ready() -> void:
    visible = enabled
    _setup_ui()
    _check_event_bus_availability()

func _setup_ui() -> void:
    # Create main panel
    var panel = Panel.new()
    panel.name = "InspectorPanel"
    panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
    panel.get_theme_stylebox("panel").bg_color = background_color
    add_child(panel)

    # Create main container
    var container = HSplitContainer.new()
    container.name = "MainContainer"
    container.size_flags_vertical = SIZE_EXPAND_FILL
    panel.add_child(container)

    # Left side - Topics list
    var topics_container = VBoxContainer.new()
    topics_container.name = "TopicsContainer"
    topics_container.size_flags_horizontal = SIZE_EXPAND_FILL
    container.add_child(topics_container)

    var topics_label = Label.new()
    topics_label.text = "EventBus Topics"
    topics_label.add_theme_color_override("font_color", text_color)
    topics_container.add_child(topics_label)

    var topics_scroll = ScrollContainer.new()
    topics_scroll.name = "TopicsScroll"
    topics_scroll.size_flags_vertical = SIZE_EXPAND_FILL
    topics_container.add_child(topics_scroll)

    var topics_list = ItemList.new()
    topics_list.name = "TopicsList"
    topics_list.size_flags_vertical = SIZE_EXPAND_FILL
    topics_list.item_selected.connect(_on_topic_selected)
    topics_scroll.add_child(topics_list)

    # Right side - Events details
    var events_container = VBoxContainer.new()
    events_container.name = "EventsContainer"
    events_container.size_flags_horizontal = SIZE_EXPAND_FILL
    container.add_child(events_container)

    var events_label = Label.new()
    events_label.text = "Topic Events"
    events_label.add_theme_color_override("font_color", text_color)
    events_container.add_child(events_label)

    var events_scroll = ScrollContainer.new()
    events_scroll.name = "EventsScroll"
    events_scroll.size_flags_vertical = SIZE_EXPAND_FILL
    events_container.add_child(events_scroll)

    var events_text = RichTextLabel.new()
    events_text.name = "EventsText"
    events_text.size_flags_vertical = SIZE_EXPAND_FILL
    events_text.scroll_following = true
    events_text.bbcode_enabled = true
    events_text.add_theme_font_size_override("normal_font_size", font_size)
    events_text.add_theme_color_override("default_color", text_color)
    events_scroll.add_child(events_text)

    # Control buttons
    var button_container = HBoxContainer.new()
    button_container.name = "ButtonContainer"
    panel.add_child(button_container)

    var refresh_button = Button.new()
    refresh_button.text = "Refresh"
    refresh_button.pressed.connect(_refresh_inspector)
    button_container.add_child(refresh_button)

    var clear_button = Button.new()
    clear_button.text = "Clear"
    clear_button.pressed.connect(_clear_history)
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
    anchors_preset = PRESET_FULL_RECT
    panel.custom_minimum_size = Vector2(1000, 500)

func _check_event_bus_availability() -> void:
    _event_bus_available = Engine.has_singleton("EventBus")

    if _event_bus_available:
        var event_bus = Engine.get_singleton("EventBus")

        # Subscribe to all events
        event_bus.call("sub_all", _on_event_received)

        # Connect to EventTopics if available
        if Engine.has_singleton("EventTopics"):
            var event_topics = Engine.get_singleton("EventTopics")
            if event_topics.has_method("get_all_topics"):
                var all_topics = event_topics.call("get_all_topics")
                _topic_filters = all_topics

        _refresh_inspector()
    else:
        _add_event_to_history("debug/error", {
            "message": "EventBus singleton not available",
            "timestamp_ms": Time.get_ticks_msec()
        })

func _process(delta: float) -> void:
    if not enabled or not visible or not _event_bus_available:
        return

    _refresh_timer += delta
    if _refresh_timer >= auto_refresh_interval:
        _refresh_timer = 0.0
        if not _is_paused:
            _refresh_display()

func _on_event_received(envelope: Dictionary) -> void:
    if _is_paused:
        return

    var topic: String = envelope.get("topic", "unknown")
    var payload: Dictionary = envelope.get("payload", {})

    _add_event_to_history(topic, payload)

func _add_event_to_history(topic: String, event_data: Dictionary) -> void:
    if not _event_history.has(topic):
        _event_history[topic] = []

    var events = _event_history[topic]
    events.append({
        "data": event_data,
        "timestamp_ms": Time.get_ticks_msec(),
        "frame": Engine.get_frames_drawn()
    })

    # Limit events per topic
    if events.size() > max_events_per_topic:
        events.remove_at(0)

    _event_history[topic] = events

func _refresh_inspector() -> void:
    if not _event_bus_available:
        return

    # Get current subscriptions
    var event_bus = Engine.get_singleton("EventBus")
    var current_subs = {}

    if event_bus.has_method("get_subscriptions"):
        current_subs = event_bus.call("get_subscriptions")

    _add_event_to_history("debug/inspector_refresh", {
        "subscription_count": current_subs.size(),
        "tracked_topics": _event_history.keys().size(),
        "timestamp_ms": Time.get_ticks_msec()
    })

    _refresh_display()
    inspector_refreshed.emit()

func _refresh_display() -> void:
    var topics_list = get_node_or_null("InspectorPanel/MainContainer/TopicsContainer/TopicsScroll/TopicsList") as ItemList
    var events_text = get_node_or_null("InspectorPanel/MainContainer/EventsContainer/EventsScroll/EventsText") as RichTextLabel

    if not topics_list or not events_text:
        return

    # Update topics list
    topics_list.clear()

    var sorted_topics = _event_history.keys()
    sorted_topics.sort()

    for topic in sorted_topics:
        var event_count = _event_history[topic].size()
        var display_text = "%s (%d events)" % [topic, event_count]
        topics_list.add_item(display_text)

        # Highlight if this is the selected topic
        if topic == _selected_topic:
            topics_list.set_item_custom_fg_color(topics_list.get_item_count() - 1, Color.YELLOW)

    # Update events display
    events_text.clear()

    if _selected_topic and _event_history.has(_selected_topic):
        events_text.append_text("[b]Topic: " + _selected_topic + "[/b]\n\n")

        var events = _event_history[_selected_topic]
        for i in range(events.size() - 1, -1, -1):  # Show newest first
            var event_data = events[i]
            var timestamp = event_data.get("timestamp_ms", 0)
            var frame = event_data.get("frame", 0)
            var data = event_data.get("data", {})

            events_text.append_text("[u]Event %d - Frame %d[/u]\n" % [events.size() - i, frame])
            events_text.append_text("Time: %d ms\n" % timestamp)

            # Format the event data
            var formatted_data = _format_event_data(data)
            events_text.append_text("Data: " + formatted_data + "\n\n")
    else:
        events_text.append_text("Select a topic to view events")

func _format_event_data(data: Dictionary, indent_level: int = 0) -> String:
    var indent = "  ".repeat(indent_level)
    var result = ""

    if typeof(data) == TYPE_DICTIONARY:
        result += "{"
        var first = true
        for key in data:
            if not first:
                result += ", "
            result += "\n" + indent + "  " + str(key) + ": "
            result += _format_event_data(data[key], indent_level + 1)
            first = false
        result += "\n" + indent + "}"
    elif typeof(data) == TYPE_ARRAY:
        result += "["
        for i in range(data.size()):
            if i > 0:
                result += ", "
            result += _format_event_data(data[i], indent_level)
        result += "]"
    else:
        result += str(data)

    return result

func _on_topic_selected(index: int) -> void:
    var topics_list = get_node_or_null("InspectorPanel/MainContainer/TopicsContainer/TopicsScroll/TopicsList") as ItemList
    if not topics_list:
        return

    var selected_text = topics_list.get_item_text(index)
    _selected_topic = selected_text.split(" (")[0]  # Remove event count

    topic_selected.emit(_selected_topic)
    _refresh_display()

func _clear_history() -> void:
    _event_history.clear()
    _selected_topic = ""
    _refresh_display()

func _toggle_pause() -> void:
    _is_paused = not _is_paused
    var pause_button = get_node_or_null("InspectorPanel/ButtonContainer/Pause") as Button
    if pause_button:
        pause_button.text = "Resume" if _is_paused else "Pause"

func _show_filter_dialog() -> void:
    # TODO: Implement filter dialog UI
    pass

func add_topic_filter(filter: String) -> void:
    if not _topic_filters.has(filter):
        _topic_filters.append(filter)

func remove_topic_filter(filter: String) -> void:
    _topic_filters.erase(filter)

func clear_topic_filters() -> void:
    _topic_filters.clear()

func set_max_events_per_topic(max_events: int) -> void:
    max_events_per_topic = max(1, max_events)

func get_tracked_topics() -> Array[String]:
    return _event_history.keys()

func get_event_count(topic: String) -> int:
    if not _event_history.has(topic):
        return 0
    return _event_history[topic].size()

func get_total_event_count() -> int:
    var total = 0
    for topic in _event_history:
        total += _event_history[topic].size()
    return total

func toggle_visibility() -> void:
    visible = not visible

func set_enabled(enable: bool) -> void:
    enabled = enable
    visible = enabled and visible

func is_enabled() -> bool:
    return enabled

func refresh() -> void:
    _refresh_inspector()

func get_event_bus_status() -> Dictionary:
    return {
        "available": _event_bus_available,
        "tracked_topics": get_tracked_topics().size(),
        "total_events": get_total_event_count(),
        "paused": _is_paused
    }
