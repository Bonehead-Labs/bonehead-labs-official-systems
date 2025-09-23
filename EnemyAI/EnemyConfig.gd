class_name EnemyConfig
extends Resource

## Configuration resource for enemy stats and behavior parameters.
## Allows designers to tune enemy behavior without code changes.

@export_category("Stats")
@export var max_health: float = 100.0
@export var movement_speed: float = 100.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0
@export var jump_force: float = 300.0

@export_category("Combat")
@export var attack_damage: float = 25.0
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 1.5
@export var projectile_speed: float = 200.0
@export var knockback_resistance: float = 1.0

@export_category("Perception")
@export var detection_range: float = 150.0
@export var field_of_view_angle: float = 90.0  # degrees
@export var hearing_range: float = 200.0
@export var alert_duration: float = 10.0      # how long to stay alert after losing player

@export_category("Navigation")
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 120.0
@export var path_update_interval: float = 0.5
@export var waypoint_tolerance: float = 10.0
@export var use_navigation: bool = true

@export_category("Behavior")
@export var faction: String = "enemy"
@export var friendly_fire: bool = false
@export var can_jump: bool = false
@export var can_fly: bool = false
@export var stun_resistance: float = 0.0

@export_category("Loot")
@export var loot_table_path: String = ""
@export var experience_value: int = 10

@export_category("Visual")
@export var sprite_scale: Vector2 = Vector2.ONE
@export var animation_speed: float = 1.0
@export var death_animation_duration: float = 2.0
@export var debug_draw_perception: bool = false
@export var debug_draw_fov: bool = true

@export_category("Analytics")
@export var emit_analytics: bool = true
@export var analytics_category: String = "enemy"

## Create a configuration for a specific enemy type
static func create_basic_enemy() -> EnemyConfig:
    var config = EnemyConfig.new()
    config.max_health = 50.0
    config.movement_speed = 80.0
    config.attack_damage = 15.0
    config.detection_range = 120.0
    config.patrol_speed = 40.0
    config.chase_speed = 100.0
    return config

static func create_elite_enemy() -> EnemyConfig:
    var config = EnemyConfig.new()
    config.max_health = 200.0
    config.movement_speed = 120.0
    config.attack_damage = 40.0
    config.detection_range = 180.0
    config.patrol_speed = 60.0
    config.chase_speed = 150.0
    config.faction = "elite_enemy"
    config.experience_value = 50
    return config

static func create_boss_enemy() -> EnemyConfig:
    var config = EnemyConfig.new()
    config.max_health = 1000.0
    config.movement_speed = 80.0
    config.attack_damage = 75.0
    config.detection_range = 250.0
    config.patrol_speed = 30.0
    config.chase_speed = 120.0
    config.faction = "boss"
    config.experience_value = 200
    config.death_animation_duration = 5.0
    return config

## Validate configuration values
func validate() -> bool:
    var errors: Array[String] = []

    if max_health <= 0:
        errors.append("max_health must be positive")
    if movement_speed < 0:
        errors.append("movement_speed cannot be negative")
    if attack_damage < 0:
        errors.append("attack_damage cannot be negative")
    if detection_range <= 0:
        errors.append("detection_range must be positive")
    if field_of_view_angle <= 0 or field_of_view_angle > 360:
        errors.append("field_of_view_angle must be between 0 and 360")
    if faction.is_empty():
        errors.append("faction cannot be empty")

    if not errors.is_empty():
        push_error("EnemyConfig validation failed: " + ", ".join(errors))
        return false

    return true

## Get configuration as dictionary (for save/load or analytics)
func to_dictionary() -> Dictionary:
    return {
        "max_health": max_health,
        "movement_speed": movement_speed,
        "acceleration": acceleration,
        "friction": friction,
        "jump_force": jump_force,
        "attack_damage": attack_damage,
        "attack_range": attack_range,
        "attack_cooldown": attack_cooldown,
        "projectile_speed": projectile_speed,
        "knockback_resistance": knockback_resistance,
        "detection_range": detection_range,
        "field_of_view_angle": field_of_view_angle,
        "hearing_range": hearing_range,
        "alert_duration": alert_duration,
        "patrol_speed": patrol_speed,
        "chase_speed": chase_speed,
        "path_update_interval": path_update_interval,
        "waypoint_tolerance": waypoint_tolerance,
        "use_navigation": use_navigation,
        "faction": faction,
        "friendly_fire": friendly_fire,
        "can_jump": can_jump,
        "can_fly": can_fly,
        "stun_resistance": stun_resistance,
        "loot_table_path": loot_table_path,
        "experience_value": experience_value,
        "sprite_scale": sprite_scale,
        "animation_speed": animation_speed,
        "death_animation_duration": death_animation_duration,
        "debug_draw_perception": debug_draw_perception,
        "debug_draw_fov": debug_draw_fov,
        "emit_analytics": emit_analytics,
        "analytics_category": analytics_category
    }
