extends Label

@export var controller_path: NodePath
@export var show_last_event: bool = false

var _controller: _PlayerController2D
var _last_event: StringName = StringName()

func _ready() -> void:
    _resolve_controller()
    _update_text()

func _process(_delta: float) -> void:
    if _controller == null:
        _resolve_controller()

func _resolve_controller() -> void:
    if controller_path.is_empty():
        return
    var node := get_node_or_null(controller_path)
    if node is _PlayerController2D:
        _controller = node
        if not _controller.state_changed.is_connected(_on_state_changed):
            _controller.state_changed.connect(_on_state_changed)
        if not _controller.state_event.is_connected(_on_state_event):
            _controller.state_event.connect(_on_state_event)
        _update_text()

func _on_state_changed(_previous: StringName, current: StringName) -> void:
    text = _format_text(current)

func _on_state_event(event: StringName, _data: Variant) -> void:
    if show_last_event:
        _last_event = event
        _update_text()

func _update_text() -> void:
    var current_state := StringName("unknown")
    if _controller:
        current_state = _controller.get_current_state()
    text = _format_text(current_state)

func _format_text(current: StringName) -> String:
    if show_last_event and _last_event != StringName():
        return "State: %s (event: %s)" % [current, _last_event]
    return "State: %s" % current
