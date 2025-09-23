extends Area2D
class_name Portal

## Portal node for level transitions with entry/exit conditions.

const LevelLoaderScript = preload("res://World/LevelLoader.gd")

@export var target_scene: String = ""
@export var target_spawn_point: String = ""
@export var entry_conditions: Dictionary = {}
@export var exit_payload: Dictionary = {}

var _teleporting_bodies: Array[Node] = []

signal portal_entered(body: Node, portal: Portal)
signal portal_exited(body: Node, portal: Portal)
signal portal_activated(body: Node, portal: Portal)

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if _teleporting_bodies.has(body):
        return

    portal_entered.emit(body, self)

    if can_use_portal(body):
        _teleport_body(body)

func _on_body_exited(body: Node) -> void:
    _teleporting_bodies.erase(body)
    portal_exited.emit(body, self)

func can_use_portal(body: Node) -> bool:
    # Check entry conditions
    for condition in entry_conditions:
        var required_value = entry_conditions[condition]
        match condition:
            "has_item":
                if not body.has_node("InventoryLite"):
                    return false
                var inv = body.get_node("InventoryLite")
                if not inv.call("has_item", required_value):
                    return false
            "has_tag":
                if not body.is_in_group(required_value):
                    return false
            "min_health":
                if body.has_node("HealthComponent"):
                    var health_comp = body.get_node("HealthComponent")
                    var current_health: float = health_comp.call("get_current_health")
                    if current_health < required_value:
                        return false
            _:
                push_warning("Portal: unknown condition: " + condition)

    return true

func _teleport_body(body: Node) -> void:
    if target_scene.is_empty():
        push_error("Portal: target_scene is empty")
        return

    _teleporting_bodies.append(body)

    # Prepare payload
    var payload: Dictionary = exit_payload.duplicate(true)
    payload["spawn_point"] = target_spawn_point
    payload["source_portal"] = name
    payload["teleported_body"] = body.name

    portal_activated.emit(body, self)

    # Emit event for analytics
    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/portal_used", {
            "portal": name,
            "body": String(body.name),
            "target_scene": target_scene,
            "target_spawn": target_spawn_point
        })

    # Use LevelLoader to handle the transition
    var success: bool = LevelLoaderScript.load_level(target_scene, payload)

    if not success:
        _teleporting_bodies.erase(body)
        push_error("Portal: failed to load target scene: " + target_scene)

func set_entry_condition(condition: String, value: Variant) -> void:
    entry_conditions[condition] = value

func set_exit_payload(key: String, value: Variant) -> void:
    exit_payload[key] = value

func get_target_scene() -> String:
    return target_scene

func get_target_spawn_point() -> String:
    return target_spawn_point
