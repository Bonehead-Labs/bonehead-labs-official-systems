extends Control

## Minimal scene overlay that shows how to subscribe to EventBus topics,
## publish events, and toggle the EventBusInspector while running the sample.

const LOG_LINE_LIMIT := 12
const PANEL_SIZE := Vector2(420, 260)

var _log_view: RichTextLabel
var _log_lines: Array[String] = []
var _emit_button: Button
var _input_action_listener := Callable()
var _debug_log_listener := Callable()
var _catch_all_listener := Callable()
func _ready() -> void:
	if not (Engine.is_editor_hint() or OS.has_feature("debug")):
		return
	if not EventBus:
		push_error("EventBusDemo: EventBus autoload is missing; demo UI disabled.")
		return

	anchors_preset = PRESET_FULL_RECT
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	_build_ui()
	_setup_eventbus_listeners()

	_log_event(&"demo/startup", {"message": "EventBus demo initialized. Move, jump, or attack to fire input events."}) # demo StringName &"demo/startup", use EventTopics in practise.
	EventBus.pub(EventTopics.DEBUG_LOG, {
		"msg": "EventBus demo is ready. Press the demo button or use input actions to publish events.",
		"level": "INFO",
		"source": "EventBusDemo"
	})

func _exit_tree() -> void:
	if not EventBus:
		return
	if _input_action_listener.is_valid():
		EventBus.unsub(EventTopics.INPUT_ACTION, _input_action_listener)
	if _debug_log_listener.is_valid():
		EventBus.unsub(EventTopics.DEBUG_LOG, _debug_log_listener)
	if _catch_all_listener.is_valid():
		EventBus.unsub_all(_catch_all_listener)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "EventBusDemoPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 16
	panel.offset_top = 16
	panel.custom_minimum_size = PANEL_SIZE
	# Allow the panel to receive mouse input
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.custom_minimum_size = PANEL_SIZE
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(layout)

	var title := Label.new()
	title.text = "EventBus Demo"
	title.clip_text = true
	layout.add_child(title)

	var instructions := Label.new()
	instructions.text = "EventBus demo. Press movement keys, jump, or attack to see INPUT_ACTION events."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(instructions)

	_emit_button = Button.new()
	_emit_button.text = "Emit Demo DEBUG_LOG Event"
	_emit_button.pressed.connect(_on_emit_button_pressed)
	layout.add_child(_emit_button)

	_log_view = RichTextLabel.new()
	_log_view.name = "LogView"
	_log_view.scroll_active = true
	_log_view.fit_content = false
	_log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_view.custom_minimum_size = Vector2(PANEL_SIZE.x, PANEL_SIZE.y - 120)
	_log_view.text = "Waiting for EventBus traffic..."
	layout.add_child(_log_view)

func _setup_eventbus_listeners() -> void:
	_input_action_listener = Callable(self, "_on_input_action_event")
	_debug_log_listener = Callable(self, "_on_debug_log_event")
	_catch_all_listener = Callable(self, "_on_event_catch_all")
	EventBus.sub(EventTopics.INPUT_ACTION, _input_action_listener)
	EventBus.sub(EventTopics.DEBUG_LOG, _debug_log_listener)
	# Disable terminal spam while debugging enemy systems
	# EventBus.sub_all(_catch_all_listener)

func _on_emit_button_pressed() -> void:
	EventBus.pub(EventTopics.DEBUG_LOG, {
		"msg": "Demo button pressed",
		"level": "INFO",
		"source": "EventBusDemo",
		"frame": Engine.get_process_frames()
	})

func _on_input_action_event(payload: Dictionary) -> void:
	_log_event(EventTopics.INPUT_ACTION, payload)
	var action: StringName = payload.get("action", StringName(""))
	var edge: String = payload.get("edge", "")
	if action == StringName("debug_toggle_inspector") and edge == "pressed":
		_log_event(&"demo/debug_toggle", {"info": "Received debug_toggle_inspector action"})

func _on_debug_log_event(payload: Dictionary) -> void:
	_log_event(EventTopics.DEBUG_LOG, payload)

func _on_event_catch_all(_envelope: Dictionary) -> void:
	# Intentionally disabled to reduce terminal noise during enemy debugging
	pass

func _log_event(topic: StringName, payload: Dictionary) -> void:
	if _log_view == null:
		return
	var timestamp := Time.get_time_string_from_system()
	var topic_text := str(topic)
	var payload_text := "{}" if payload.is_empty() else JSON.stringify(payload)
	_log_lines.append("%s | %s -> %s" % [timestamp, topic_text, payload_text])
	while _log_lines.size() > LOG_LINE_LIMIT:
		_log_lines.pop_front()
	_log_view.text = "\n".join(_log_lines)
	# Auto-scroll to bottom to show latest entry
	_log_view.scroll_to_line(_log_view.get_line_count() - 1)
