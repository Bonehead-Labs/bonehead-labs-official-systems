extends Area2D
class_name HazardVolume

## Hazard volume that deals damage to bodies inside it.

@export var damage_per_second: float = 10.0
@export var damage_type: String = "hazard"
@export var tick_interval: float = 1.0
@export var instant_damage: float = 0.0
@export var destroy_on_contact: bool = false

var _affected_bodies: Dictionary = {} # body -> last_damage_time

signal body_entered_hazard(body: Node, hazard: HazardVolume)
signal body_exited_hazard(body: Node, hazard: HazardVolume)
signal damage_dealt(body: Node, damage: float, hazard: HazardVolume)

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
    var current_time: float = Time.get_time_dict_from_system()["hour"] * 3600 + \
                             Time.get_time_dict_from_system()["minute"] * 60 + \
                             Time.get_time_dict_from_system()["second"]

    for body in _affected_bodies.keys():
        if not is_instance_valid(body):
            _affected_bodies.erase(body)
            continue

        var last_damage: float = _affected_bodies[body]
        if current_time - last_damage >= tick_interval:
            _deal_damage_to_body(body)
            _affected_bodies[body] = current_time

func _on_body_entered(body: Node) -> void:
    if _affected_bodies.has(body):
        return

    body_entered_hazard.emit(body, self)

    # Deal instant damage on entry
    if instant_damage > 0.0:
        _deal_damage_to_body(body, instant_damage)

    # Start periodic damage
    var current_time: float = Time.get_time_dict_from_system()["hour"] * 3600 + \
                             Time.get_time_dict_from_system()["minute"] * 60 + \
                             Time.get_time_dict_from_system()["second"]
    _affected_bodies[body] = current_time

    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/hazard_entered", {
            "hazard": name,
            "body": String(body.name),
            "damage_per_second": damage_per_second,
            "instant_damage": instant_damage
        })

func _on_body_exited(body: Node) -> void:
    if _affected_bodies.erase(body):
        body_exited_hazard.emit(body, self)

        if Engine.has_singleton("EventBus"):
            Engine.get_singleton("EventBus").call("pub", &"world/hazard_exited", {
                "hazard": name,
                "body": String(body.name)
            })

    # Deal damage on exit if configured
    if destroy_on_contact and instant_damage > 0.0:
        _deal_damage_to_body(body, instant_damage)

func _deal_damage_to_body(body: Node, damage_override: float = 0.0) -> void:
    if not is_instance_valid(body):
        return

    var damage_amount: float = damage_override if damage_override > 0.0 else damage_per_second * tick_interval

    # Check if body has health component
    var health_comp = body.get_node_or_null("HealthComponent")
    if health_comp:
        var damage_info = {
            "amount": damage_amount,
            "type": damage_type,
            "source": name,
            "hazard": true
        }

        var result = health_comp.call("take_damage", damage_info)
        if result:
            damage_dealt.emit(body, damage_amount, self)

            if Engine.has_singleton("EventBus"):
                Engine.get_singleton("EventBus").call("pub", &"world/hazard_damage", {
                    "hazard": name,
                    "body": String(body.name),
                    "damage": damage_amount,
                    "damage_type": damage_type
                })

func set_damage_per_second(dps: float) -> void:
    damage_per_second = max(0.0, dps)

func set_damage_type(type: String) -> void:
    damage_type = type

func get_affected_body_count() -> int:
    return _affected_bodies.size()
