class_name MeleeAttack
extends RefCounted

const AttackModuleScript = preload("res://EnemyAI/attacks/AttackModule.gd")

var _duration: float = 0.4
var _elapsed: float = 0.0

func begin(owner: Node, _target: Node2D) -> void:
    _elapsed = 0.0
    if owner.has_method("play_animation"):
        owner.call("play_animation", "attack")

func update(_owner: Node, delta: float) -> bool:
    _elapsed += delta
    # Hitbox activation should be handled by EnemyBase.attack or a component
    return _elapsed >= _duration

func cancel(_owner: Node) -> void:
    _elapsed = 0.0

