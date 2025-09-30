class_name AttackState
extends FSMState

const EnemyBaseScript = preload("../BaseEnemy.gd")
const EnemyConfigScript = preload("../EnemyConfig.gd")
const AttackModuleScript = preload("../attacks/AttackModule.gd")

var _enemy: EnemyBaseScript
var _config: EnemyConfigScript
var _attack: AttackModuleScript
var _target: Node2D

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    super.setup(state_machine, state_owner, state_context)
    _enemy = state_context[&"enemy"]
    _config = state_context[&"config"]

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    _target = payload.get(&"target")
    _attack = payload.get(&"attack")
    if _attack and _target:
        _enemy.stop_moving()
        _enemy.flip_sprite_to_face(_target.global_position)
        _attack.begin(_enemy, _target)
        _emit_event(&"attack_started", {&"target": _target})
    else:
        machine.transition_to(&"patrol")

func update(delta: float) -> void:
    if not _enemy.is_alerted() or _target == null:
        _cancel_and_fallback(&"lost_target")
        return
    if _attack.update(_enemy, delta):
        _emit_event(&"attack_finished", {&"target": _target})
        if _enemy.can_attack_target(_target):
            machine.transition_to(&"attack", {&"target": _target, &"attack": _attack})
        else:
            machine.transition_to(&"chase", {&"reason": &"post_attack"})

func handle_event(event: StringName, _data: Variant = null) -> void:
    if event == &"interrupted":
        _cancel_and_fallback(&"interrupted")

func exit(_payload: Dictionary[StringName, Variant] = {}) -> void:
    if _attack:
        _attack.cancel(_enemy)

func _emit_event(event: StringName, data: Dictionary) -> void:
    emit_event(event, data)
    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"enemy/attack_" + event, {
            "enemy_name": _enemy.name,
            "target": String(_target.name) if _target else "unknown"
        })

func _cancel_and_fallback(reason: StringName) -> void:
    if _attack:
        _attack.cancel(_enemy)
    _emit_event(&"attack_cancelled", {&"reason": reason})
    machine.transition_to(&"chase", {&"reason": reason})

