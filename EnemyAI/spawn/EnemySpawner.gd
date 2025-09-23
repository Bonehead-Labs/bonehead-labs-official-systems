class_name EnemySpawner
extends Node2D

@export var enemy_scene: PackedScene
@export var max_alive: int = 5
@export var spawn_interval: float = 2.0

var _timer: float = 0.0
var _alive: Array[Node2D] = []

func _process(delta: float) -> void:
    _prune()
    if enemy_scene == null:
        return
    if _alive.size() >= max_alive:
        return
    _timer += delta
    if _timer >= spawn_interval:
        _timer = 0.0
        _spawn()

func _spawn() -> void:
    var inst = enemy_scene.instantiate() as Node2D
    if inst == null:
        return
    inst.global_position = global_position
    add_child(inst)
    _alive.append(inst)
    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"enemy/spawned_from_spawner", {
            "spawner": name,
            "pos": global_position
        })

func _prune() -> void:
    for i in range(_alive.size() - 1, -1, -1):
        var n = _alive[i]
        if n == null or not is_instance_valid(n) or n.get_parent() != self:
            _alive.remove_at(i)

