class_name RangedAttack
extends RefCounted

const AttackModuleScript = preload("res://EnemyAI/attacks/AttackModule.gd")

var projectile_scene: PackedScene
var muzzle_offset: Vector2 = Vector2.ZERO

func begin(owner: Node, target: Node2D) -> void:
    if projectile_scene == null:
        return
    var node := owner as Node2D
    if node == null:
        return
    var projectile = projectile_scene.instantiate()
    if projectile == null:
        return
    node.add_child(projectile)
    projectile.global_position = node.global_position + muzzle_offset
    if projectile.has_method("launch"):
        projectile.call("launch", (target.global_position - projectile.global_position).normalized())

func update(_owner: Node, _delta: float) -> bool:
    return true

func cancel(_owner: Node) -> void:
    pass

