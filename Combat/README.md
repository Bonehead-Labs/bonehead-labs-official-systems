# Combat System

A flexible combat system for Godot 4 providing health management, damage calculation, and combat utilities.

## Overview

The Combat System consists of:

- **DamageInfo**: Resource for damage/healing data with type support
- **HealthComponent**: Node for managing health, invulnerability, and combat events
- **Combat utilities**: Damage calculation, invulnerability windows, status effects

## Features

- ✅ **DamageInfo Resource**: Typed damage with metadata and modifiers
- ✅ **HealthComponent**: Health management with signals and persistence
- ✅ **Invulnerability System**: Configurable damage immunity windows
- ✅ **SaveService Integration**: Automatic health state persistence
- ✅ **EventBus Analytics**: Combat event publishing for analytics
- ✅ **Type Safety**: Strongly typed damage and health systems

## Quick Start

### 1. Add HealthComponent to Entity

```gdscript
# In your entity's _ready() method
var health_component := HealthComponent.new()
health_component.max_health = 150.0
health_component.invulnerability_duration = 0.8
add_child(health_component)

# Connect to signals
health_component.damaged.connect(_on_damaged)
health_component.died.connect(_on_died)
```

### 2. Apply Damage

```gdscript
# Create damage info
var damage := DamageInfo.create_damage(25.0, DamageInfo.DamageType.PHYSICAL, self)
health_component.take_damage(damage)

# Or for healing
var healing := DamageInfo.create_healing(10.0, self)
health_component.heal(healing)
```

### 3. Check Status

```gdscript
if health_component.is_alive():
    if health_component.is_invulnerable():
        print("Player is invulnerable!")
    else:
        print("Health: ", health_component.get_health(), "/", health_component.get_max_health())
```

## DamageInfo Resource

### Creating Damage

```gdscript
# Basic damage
var basic_damage := DamageInfo.create_damage(10.0, DamageInfo.DamageType.PHYSICAL)

# Advanced damage with metadata
var fire_damage := DamageInfo.create_damage(25.0, DamageInfo.DamageType.FIRE, self)
fire_damage.critical = true
fire_damage.with_knockback(Vector2(100, -50), 0.3)
fire_damage.with_status_effect("burning")
fire_damage.with_metadata("element", "fire")
```

### Creating Healing

```gdscript
var healing := DamageInfo.create_healing(20.0, self)
# Healing bypasses invulnerability and always applies
```

### Damage Types

- **PHYSICAL**: Standard physical damage
- **MAGICAL**: Magic-based damage
- **FIRE**: Fire elemental damage
- **ICE**: Ice elemental damage
- **LIGHTNING**: Lightning elemental damage
- **POISON**: Poison/DoT damage
- **TRUE**: Bypasses all resistances and invulnerability
- **HEALING**: Healing amount (negative damage)

## HealthComponent API

### Properties

```gdscript
@export var max_health: float = 100.0          # Maximum health capacity
@export var invulnerability_duration: float = 0.5  # Auto-invulnerability after damage
@export var auto_register_with_save_service: bool = true  # Auto-save health
```

### Health Management

```gdscript
# Get health info
var current := health_component.get_health()
var max := health_component.get_max_health()
var percentage := health_component.get_health_percentage()

# Check status
var alive := health_component.is_alive()
var full := health_component.is_full_health()
var critical := health_component.is_critical_health(0.25)  # Below 25%

# Modify health
health_component.set_health(75.0)
health_component.restore_full_health()
health_component.set_max_health(200.0)
```

### Invulnerability

```gdscript
# Make invulnerable for duration
health_component.set_invulnerable(true, 2.0)  # 2 seconds

# Check invulnerability
if health_component.is_invulnerable():
    print("Cannot take damage!")

# Get remaining time
var time_left := health_component.get_invulnerability_time()
```

### Damage/Healing

```gdscript
# Apply damage
var damage_info := DamageInfo.create_damage(30.0, DamageInfo.DamageType.FIRE)
var success := health_component.take_damage(damage_info)

# Apply healing
var heal_info := DamageInfo.create_healing(15.0)
health_component.heal(heal_info)

# Kill immediately
health_component.kill(self)
```

## Signals

### Health Events

```gdscript
# Health changes
health_component.health_changed.connect(func(old, new):
    update_health_bar(old, new)
)

# Max health changes
health_component.max_health_changed.connect(func(old, new):
    resize_health_bar(old, new)
)

# Invulnerability changes
health_component.invulnerability_changed.connect(func(is_invulnerable):
    update_invulnerability_effect(is_invulnerable)
)
```

### Combat Events

```gdscript
# Damage taken
health_component.damaged.connect(func(amount, source, damage_info):
    play_damage_effect(amount, damage_info.type)
    camera_shake(amount)
    if damage_info.critical:
        show_critical_effect()
)

# Healing received
health_component.healed.connect(func(amount, source, damage_info):
    play_healing_effect(amount)
    show_healing_numbers(amount)
)

# Entity death
health_component.died.connect(func(source, damage_info):
    play_death_animation()
    show_game_over_screen()
    disable_player_input()
)
```

## Save/Load Integration

### Automatic Persistence

HealthComponent automatically registers with SaveService and saves:

```json
{
  "health": 85.0,
  "max_health": 100.0,
  "is_invulnerable": false,
  "invulnerability_timer": 0.0
}
```

### Manual Control

```gdscript
# Disable auto-registration
health_component.auto_register_with_save_service = false

# Manual save/load
var save_data := health_component.save_data()
health_component.load_data(save_data)
```

## EventBus Integration

### Combat Analytics

All combat events are published to EventBus with detailed metadata:

```gdscript
# Damage events
{
  "amount": 25.0,
  "hp_after": 75.0,
  "source_type": "Enemy",
  "damage_type": "physical",
  "entity_position": [100, 200],
  "timestamp_ms": 1234567890
}

# Death events
{
  "amount": 0.0,
  "hp_after": 0.0,
  "source_type": "BossEnemy",
  "damage_type": "magical",
  "entity_position": [150, 180],
  "timestamp_ms": 1234567891
}
```

### Custom Events

```gdscript
# Publish custom combat events
if Engine.has_singleton("EventBus"):
    var event_bus := Engine.get_singleton("EventBus")
    event_bus.call("pub", "combat_special_attack", {
        "attacker": self,
        "target": target,
        "damage": 50,
        "effect": "stun"
    })
```

## Advanced Usage

### Custom Damage Calculation

```gdscript
class CustomHealthComponent extends HealthComponent:
    func take_damage(damage_info: DamageInfo) -> bool:
        # Apply custom damage modifiers
        var modified_amount := damage_info.amount

        # Apply elemental resistances
        match damage_info.type:
            DamageInfo.DamageType.FIRE:
                modified_amount *= 0.8  # 20% fire resistance
            DamageInfo.DamageType.ICE:
                modified_amount *= 1.2  # 20% ice vulnerability

        # Apply status effect modifiers
        if has_status("wet") and damage_info.type == DamageInfo.DamageType.LIGHTNING:
            modified_amount *= 2.0  # Wet targets take double lightning damage

        # Create modified damage info
        var modified_damage := damage_info.with_amount(modified_amount)

        # Call parent implementation
        return super.take_damage(modified_damage)
```

### Status Effect Integration

```gdscript
# Apply status effects from damage
func _on_damaged(amount: float, source: Node, damage_info: DamageInfo) -> void:
    for effect in damage_info.status_effects:
        apply_status_effect(effect, damage_info.metadata)

# Check status effects in damage calculation
func calculate_damage_modifier(damage_info: DamageInfo) -> float:
    var modifier := 1.0

    if has_status("weakened"):
        modifier *= 1.25  # Take 25% more damage when weakened

    if has_status("protected") and damage_info.type == DamageInfo.DamageType.PHYSICAL:
        modifier *= 0.75  # Take 25% less physical damage when protected

    return modifier
```

### Knockback Integration

```gdscript
func _on_damaged(amount: float, source: Node, damage_info: DamageInfo) -> void:
    # Apply knockback if specified
    if damage_info.knockback_force != Vector2.ZERO:
        apply_knockback(damage_info.knockback_force, damage_info.knockback_duration)

func apply_knockback(force: Vector2, duration: float) -> void:
    # Apply physics impulse or tween position
    velocity += force

    # Create knockback timer
    var timer := get_tree().create_timer(duration)
    timer.timeout.connect(func():
        # Reset velocity or physics state
        velocity = Vector2.ZERO
    )
```

## Testing

### Unit Tests

```bash
# Run combat system tests
godot --headless --script res://addons/gut/gut_cmdln.gd -gtest=test_combat_system
```

### Example Test

```gdscript
func test_damage_application():
    var health_component := HealthComponent.new()
    health_component.max_health = 100.0
    add_child_autofree(health_component)

    # Test basic damage
    var damage := DamageInfo.create_damage(25.0, DamageInfo.DamageType.PHYSICAL)
    health_component.take_damage(damage)

    assert_eq(health_component.get_health(), 75.0)
    assert_true(health_component.is_alive())

    # Test healing
    var healing := DamageInfo.create_healing(10.0)
    health_component.heal(healing)

    assert_eq(health_component.get_health(), 85.0)

    # Test death
    var lethal_damage := DamageInfo.create_damage(100.0, DamageInfo.DamageType.TRUE)
    health_component.take_damage(lethal_damage)

    assert_eq(health_component.get_health(), 0.0)
    assert_false(health_component.is_alive())
```

## Performance Considerations

- **Signal Emissions**: Combat signals are emitted frequently - connect only when needed
- **EventBus Publishing**: Analytics events include position data - consider throttling for high-frequency combat
- **Save Operations**: Health saves are lightweight but frequent - balance with performance
- **Invulnerability Checks**: Simple boolean checks with optional timer management

## Integration Examples

### Player Character

```gdscript
# Player.gd
func _ready():
    var health := HealthComponent.new()
    health.max_health = 150.0
    health.invulnerability_duration = 1.0
    add_child(health)

    health.damaged.connect(_on_player_damaged)
    health.died.connect(_on_player_died)

func take_damage(amount: float, source: Node, type: String = "physical"):
    var damage_info := DamageInfo.create_damage(amount, _get_damage_type(type), source)
    $HealthComponent.take_damage(damage_info)

func _on_player_damaged(amount: float, source: Node, damage_info: DamageInfo):
    # Player-specific damage response
    start_damage_flash()
    play_hurt_sound()
    update_ui_health()

func _on_player_died(source: Node, damage_info: DamageInfo):
    # Player death handling
    disable_input()
    play_death_animation()
    show_respawn_menu()
```

### Enemy Character

```gdscript
# Enemy.gd
func _ready():
    var health := HealthComponent.new()
    health.max_health = 75.0
    health.invulnerability_duration = 0.2
    add_child(health)

    health.died.connect(_on_enemy_died)

func take_damage(amount: float, source: Node):
    var damage_info := DamageInfo.create_damage(amount, DamageInfo.DamageType.PHYSICAL, source)
    $HealthComponent.take_damage(damage_info)

func _on_enemy_died(source: Node, damage_info: DamageInfo):
    # Enemy death handling
    play_death_animation()
    drop_loot()
    queue_free()
```

### Combat Manager

```gdscript
# CombatManager.gd (singleton)
func apply_damage(target: Node, amount: float, source: Node, damage_type: String = "physical"):
    if target.has_node("HealthComponent"):
        var health_component := target.get_node("HealthComponent") as HealthComponent
        var damage_info := DamageInfo.create_damage(amount, _get_damage_type(damage_type), source)
        health_component.take_damage(damage_info)
        return true
    return false

func apply_healing(target: Node, amount: float, source: Node):
    if target.has_node("HealthComponent"):
        var health_component := target.get_node("HealthComponent") as HealthComponent
        var healing_info := DamageInfo.create_healing(amount, source)
        health_component.heal(healing_info)
        return true
    return false
```

## Error Handling

### Invalid Damage

```gdscript
var damage_info := DamageInfo.create_damage(-5.0)  # Invalid negative damage
if not health_component.take_damage(damage_info):
    push_warning("Failed to apply invalid damage")
```

### Missing HealthComponent

```gdscript
if not entity.has_node("HealthComponent"):
    push_error("Entity missing HealthComponent for combat")
    return
```

### Save/Load Errors

```gdscript
func save_combat_state() -> Dictionary:
    var data := {}
    if has_node("HealthComponent"):
        data["health"] = $HealthComponent.save_data()
    return data

func load_combat_state(data: Dictionary) -> void:
    if data.has("health") and has_node("HealthComponent"):
        $HealthComponent.load_data(data["health"])
```

This Combat System provides a solid foundation for health management and damage calculation while remaining flexible for various game types and combat styles.
