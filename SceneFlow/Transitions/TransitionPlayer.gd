extends CanvasLayer

const FlowTransitionLibrary = preload("res://SceneFlow/Transitions/TransitionLibrary.gd")
const FlowTransition = preload("res://SceneFlow/Transitions/TransitionResource.gd")

@export var animation_player_path: NodePath
var _animation_player: AnimationPlayer
var _active_transition: FlowTransition

func _ready() -> void:
    _animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
    if _animation_player == null:
        push_warning("FlowTransitionPlayer requires AnimationPlayer node")

func play_transition(transition: FlowTransition, is_enter: bool) -> void:
    if transition == null or _animation_player == null:
        return
    _active_transition = transition
    var anim := transition.enter_animation if is_enter else transition.exit_animation
    if anim.is_empty() or not _animation_player.has_animation(anim):
        return
    _animation_player.play(anim)

func is_playing() -> bool:
    if _animation_player == null:
        return false
    return _animation_player.is_playing()
