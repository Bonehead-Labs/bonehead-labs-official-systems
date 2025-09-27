extends Control

## Minimal scene overlay that shows how to subscribe to EventBus topics,
## publish events, and toggle the EventBusInspector while running the sample.

const LOG_LINE_LIMIT := 12
const PANEL_SIZE := Vector2(420, 260)

var _log_view: RichTextLabel
var _log_lines: Array[String] = []
var _emit_button: Button
var _inspector: EventBusInspector
var _input_action_listener := Callable()
var _debug_log_listener := Callable()
var _catch_all_listener := Callable()
var _event_bus: Node

func _ready() -> void:
	if not (Engine.is_editor_hint() or OS.has_feature("debug")):
		return
	_event_bus = _locate_autoload(StringName("EventBus"))
	if _event_bus == null:
		push_error("EventBusDemo: EventBus autoload is missing; demo UI disabled.")
		return

	anchors_preset = PRESET_FULL_RECT
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	_build_ui()
	_setup_eventbus_listeners()
	_spawn_inspector()

	_log_event(&"demo/startup", {"message": "EventBus demo initialized. Move, jump, or attack to fire input events."})
	_event_bus.call("pub", EventTopics.DEBUG_LOG, {
		"msg": "EventBus demo is ready. Press the demo button or use input actions to publish events.",
		"level": "INFO",
		"source": "EventBusDemo"
	})

func _exit_tree() -> void:
	if _event_bus == null:
		return
	if _input_action_listener.is_valid():
		_event_bus.call("unsub", EventTopics.INPUT_ACTION, _input_action_listener)
	if _debug_log_listener.is_valid():
		_event_bus.call("unsub", EventTopics.DEBUG_LOG, _debug_log_listener)
	if _catch_all_listener.is_valid():
		_event_bus.call("unsub_all", _catch_all_listener)

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
	instructions.text = "Press movement keys, jump, or attack to see INPUT_ACTION events. Press F4 (debug_toggle_inspector) to open the inspector."
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
	_event_bus.call("sub", EventTopics.INPUT_ACTION, _input_action_listener)
	_event_bus.call("sub", EventTopics.DEBUG_LOG, _debug_log_listener)
	_event_bus.call("sub_all", _catch_all_listener)

func _spawn_inspector() -> void:
	_inspector = EventBusInspector.new()
	_inspector.name = "EventBusInspector"
	_inspector.enabled = true
	_inspector.visible = false
	_inspector.anchors_preset = PRESET_FULL_RECT
	_inspector.z_index = 100
	add_child(_inspector)

func _on_emit_button_pressed() -> void:
	_event_bus.call("pub", EventTopics.DEBUG_LOG, {
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
		_toggle_inspector()

func _on_debug_log_event(payload: Dictionary) -> void:
	_log_event(EventTopics.DEBUG_LOG, payload)

func _on_event_catch_all(envelope: Dictionary) -> void:
	var topic: StringName = envelope.get("topic", StringName("unknown"))
	var payload: Dictionary = envelope.get("payload", {})
	var summary := "{}" if payload.is_empty() else JSON.stringify(payload)
	print("EventBus catch-all ->", topic, summary)

func _toggle_inspector() -> void:
	if _inspector == null:
		return
	_inspector.visible = not _inspector.visible
	_log_event(&"demo/inspector", {"visible": _inspector.visible})

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

func _locate_autoload(singleton_name: StringName) -> Node:
	var root := get_tree().root
	if root == null:
		return null
	var node := root.get_node_or_null(NodePath(String(singleton_name)))
	if node:
		return node
	var abs_path := NodePath("/root/%s" % singleton_name)
	return root.get_node_or_null(abs_path)
