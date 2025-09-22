class_name PlayerAnimationDriver
extends Node

## Bridges PlayerController state changes to AnimationPlayer or AnimatedSprite2D nodes.

@export var controller_path: NodePath
@export var animation_player_path: NodePath
@export var animated_sprite_path: NodePath
@export var state_animation_map: Dictionary = {}
@export var event_animation_map: Dictionary = {}
@export var fallback_animation: StringName = StringName()
@export var allow_events_to_override_state: bool = true

var _controller: _PlayerController2D
var _animation_player: AnimationPlayer
var _animated_sprite: AnimatedSprite2D
var _override_animation: StringName = StringName()
var _override_source: StringName = StringName()

func _ready() -> void:
    _resolve_nodes()
    _apply_initial_state()

func _exit_tree() -> void:
    if _controller:
        if _controller.state_changed.is_connected(_on_state_changed):
            _controller.state_changed.disconnect(_on_state_changed)
        if _controller.state_event.is_connected(_on_state_event):
            _controller.state_event.disconnect(_on_state_event)

func set_animation_override(animation: StringName, source: StringName = StringName()) -> void:
    """Force a specific animation to play until cleared (useful for cutscenes)."""
    if animation == StringName():
        return
    _override_animation = animation
    _override_source = source
    _play_animation(animation)

func clear_animation_override(source: StringName = StringName()) -> void:
    """Clear a previously set override. Optional source must match the setter."""
    if _override_animation == StringName():
        return
    if source != StringName() and source != _override_source:
        return
    _override_animation = StringName()
    _override_source = StringName()
    _apply_current_state_animation()

func refresh_controller(controller: _PlayerController2D) -> void:
    _disconnect_controller()
    _controller = controller
    _connect_controller()
    _apply_current_state_animation()

func _resolve_nodes() -> void:
    if controller_path != NodePath():
        var node := get_node_or_null(controller_path)
        if node is _PlayerController2D:
            _controller = node
    _connect_controller()
    if animation_player_path != NodePath():
        var player_node := get_node_or_null(animation_player_path)
        if player_node is AnimationPlayer:
            _animation_player = player_node
    if animated_sprite_path != NodePath():
        var sprite_node := get_node_or_null(animated_sprite_path)
        if sprite_node is AnimatedSprite2D:
            _animated_sprite = sprite_node

func _connect_controller() -> void:
    if _controller == null:
        return
    if not _controller.state_changed.is_connected(_on_state_changed):
        _controller.state_changed.connect(_on_state_changed)
    if not _controller.state_event.is_connected(_on_state_event):
        _controller.state_event.connect(_on_state_event)

func _disconnect_controller() -> void:
    if _controller == null:
        return
    if _controller.state_changed.is_connected(_on_state_changed):
        _controller.state_changed.disconnect(_on_state_changed)
    if _controller.state_event.is_connected(_on_state_event):
        _controller.state_event.disconnect(_on_state_event)
    _controller = null

func _apply_initial_state() -> void:
    if _controller == null:
        return
    _apply_current_state_animation()

func _on_state_changed(_previous: StringName, current: StringName) -> void:
    if _override_animation != StringName():
        return
    var animation_name := _animation_for_state(current)
    if animation_name == StringName():
        animation_name = fallback_animation
    _play_animation(animation_name)

func _on_state_event(event: StringName, _data: Variant) -> void:
    if not allow_events_to_override_state:
        return
    if _override_animation != StringName():
        return
    var animation_name := _animation_for_event(event)
    if animation_name == StringName():
        return
    _play_animation(animation_name)

func _apply_current_state_animation() -> void:
    if _controller == null or _override_animation != StringName():
        return
    var current_state := _controller.get_current_state()
    var animation_name := _animation_for_state(current_state)
    if animation_name == StringName():
        animation_name = fallback_animation
    _play_animation(animation_name)

func _animation_for_state(state_id: StringName) -> StringName:
    if state_animation_map.is_empty():
        return StringName()
    if state_animation_map.has(state_id):
        return _coerce_string_name(state_animation_map[state_id])
    var state_key := String(state_id)
    if state_animation_map.has(state_key):
        return _coerce_string_name(state_animation_map[state_key])
    return StringName()

func _animation_for_event(event_id: StringName) -> StringName:
    if event_animation_map.is_empty():
        return StringName()
    if event_animation_map.has(event_id):
        return _coerce_string_name(event_animation_map[event_id])
    var event_key := String(event_id)
    if event_animation_map.has(event_key):
        return _coerce_string_name(event_animation_map[event_key])
    return StringName()

func _coerce_string_name(value: Variant) -> StringName:
    if value is StringName:
        return value
    if value is String:
        return StringName(value)
    return StringName()

func _play_animation(animation_name: StringName) -> void:
    if animation_name == StringName():
        return
    var played: bool = false
    if _animation_player:
        if _animation_player.has_animation(animation_name):
            _animation_player.play(animation_name)
            played = true
        else:
            push_warning("AnimationPlayer missing animation '%s'" % animation_name)
    if not played and _animated_sprite:
        var frames: SpriteFrames = _animated_sprite.sprite_frames
        if frames and frames.has_animation(animation_name):
            _animated_sprite.play(animation_name)
            played = true
        elif frames == null:
            push_warning("AnimatedSprite2D missing SpriteFrames resource")
        else:
            push_warning("AnimatedSprite2D missing animation '%s'" % animation_name)
    if not played and fallback_animation != StringName() and animation_name != fallback_animation:
        _play_animation(fallback_animation)
*** End Patch
