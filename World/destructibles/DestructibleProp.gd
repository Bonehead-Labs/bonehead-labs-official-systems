extends StaticBody2D
class_name DestructibleProp

## Destructible prop with health integration and loot hooks.

const HealthComponentScript = preload("res://Combat/HealthComponent.gd")
const DeathHandlerScript = preload("res://Combat/DeathHandler.gd")

@export var max_health: float = 100.0
@export var loot_table_path: String = ""
@export var destroy_on_death: bool = true
@export var respawn_time: float = 0.0  # 0 = no respawn

var _health_component: HealthComponentScript
var _death_handler: DeathHandlerScript
var _is_destroyed: bool = false

signal prop_damaged(prop: DestructibleProp, damage: float, source: Node)
signal prop_destroyed(prop: DestructibleProp, source: Node)
signal prop_respawned(prop: DestructibleProp)

func _ready() -> void:
    _setup_health_component()
    _setup_death_handler()
    _connect_signals()

func _setup_health_component() -> void:
    _health_component = HealthComponentScript.new()
    _health_component.max_health = max_health
    _health_component.auto_register_with_save_service = false
    add_child(_health_component)

func _setup_death_handler() -> void:
    _death_handler = DeathHandlerScript.new()
    _death_handler.respawn_enabled = respawn_time > 0.0
    _death_handler.death_animation_duration = 0.5  # Quick destruction
    _death_handler.emit_analytics = true
    add_child(_death_handler)

func _connect_signals() -> void:
    if _health_component:
        _health_component.died.connect(_on_died)
        _health_component.damaged.connect(_on_damaged)

    if _death_handler:
        _death_handler.respawned.connect(_on_respawned)

func take_damage(damage_info: Dictionary) -> bool:
    if _is_destroyed or not _health_component:
        return false

    var result: bool = _health_component.call("take_damage", damage_info)
    return result

func _on_damaged(_source: Node, damage_info: Dictionary) -> void:
    var damage_amount: float = damage_info.get("amount", 0.0)
    var source: Node = damage_info.get("source", null)

    prop_damaged.emit(self, damage_amount, source)

    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/prop_damaged", {
            "prop": name,
            "damage": damage_amount,
            "source": String(source.name) if source else "unknown",
            "health_remaining": _health_component.call("get_current_health")
        })

func _on_died(_source: Node, _damage_info: Dictionary) -> void:
    _is_destroyed = true
    prop_destroyed.emit(self, _source)

    # Generate loot if loot table is specified
    if not loot_table_path.is_empty():
        _generate_loot()

    # Handle destruction
    if destroy_on_death:
        _start_destruction_sequence()

    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/prop_destroyed", {
            "prop": name,
            "source": String(_source.name) if _source else "unknown",
            "position": global_position,
            "loot_table": loot_table_path
        })

func _on_respawned() -> void:
    _is_destroyed = false
    prop_respawned.emit(self)

    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/prop_respawned", {
            "prop": name,
            "position": global_position
        })

func _generate_loot() -> void:
    # TODO: Load loot table and generate items
    # This would integrate with Items & Economy system
    # For now, just emit a signal that other systems can listen to
    pass

func _start_destruction_sequence() -> void:
    # Visual destruction effects
    modulate = Color(0.5, 0.5, 0.5, 0.8)

    # Schedule removal
    var timer = Timer.new()
    timer.wait_time = _death_handler.death_animation_duration
    timer.one_shot = true
    timer.timeout.connect(_on_destruction_complete)
    add_child(timer)
    timer.start()

func _on_destruction_complete() -> void:
    if destroy_on_death:
        queue_free()

func heal(amount: float) -> bool:
    if _is_destroyed or not _health_component:
        return false

    return _health_component.call("heal", amount)

func get_current_health() -> float:
    if not _health_component:
        return 0.0
    return _health_component.call("get_current_health")

func get_max_health() -> float:
    return max_health

func is_destroyed() -> bool:
    return _is_destroyed

func repair() -> void:
    if _health_component:
        _health_component.call("heal", max_health)
    _is_destroyed = false
    modulate = Color.WHITE

func set_loot_table(path: String) -> void:
    loot_table_path = path

func get_loot_table() -> String:
    return loot_table_path
