# Combat System

A flexible combat system for Godot 4 providing health management, damage calculation, and combat utilities.

## Overview

The Combat System consists of:

- **DamageInfo**: Resource for damage/healing data with type support
- **HealthComponent**: Node for managing health, invulnerability, and combat events
- **HurtboxComponent**: Areas that can receive damage from hitboxes
- **HitboxComponent**: Areas that can deal damage to hitboxes
- **KnockbackResolver**: Physics-based knockback with multiple behavior modes
- **StatusEffectManager**: DoT, buffs, debuffs with stacking rules and timers
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

## Hitbox/Hurtbox Framework

The hitbox/hurtbox system provides collision-based damage detection using Area2D nodes.

### HurtboxComponent

Hurtboxes define areas on entities that can receive damage. They automatically connect to HealthComponent and apply damage when overlapping with active hitboxes.

```gdscript
# Attach to player/enemy
var hurtbox := HurtboxComponent.new()
hurtbox.faction = "player"
hurtbox.friendly_fire = false
hurtbox.immune_factions = ["player"]  # Immune to other players
entity.add_child(hurtbox)

# Connect signals
hurtbox.damage_taken.connect(_on_damage_taken)
```

#### Hurtbox Properties

```gdscript
@export var health_component_path: NodePath = ^".."  # Path to HealthComponent
@export var faction: String = "neutral"              # Entity faction
@export var enabled: bool = true                      # Enable/disable hurtbox
@export var friendly_fire: bool = false               # Allow same-faction damage
@export var immune_factions: Array[String] = []       # Factions that cannot damage
```

#### Hurtbox Signals

```gdscript
hurtbox.hurtbox_hit.connect(func(hitbox, damage_info):
    # Damage was applied
    camera_shake(damage_info.amount)
)

hurtbox.damage_taken.connect(func(amount, source, damage_info):
    # React to damage
    play_hurt_sound()
    show_damage_numbers(amount)
)
```

### HitboxComponent

Hitboxes define areas that deal damage to overlapping hurtboxes. They must be activated to deal damage and can have configurable damage parameters.

```gdscript
# Attach to weapon/projectile
var hitbox := HitboxComponent.new()
hitbox.faction = "enemy"
hitbox.damage_amount = 25.0
hitbox.damage_type = DamageInfo.DamageType.PHYSICAL
hitbox.activation_duration = 0.3  # Active for 0.3 seconds
weapon.add_child(hitbox)

# Activate during attack
hitbox.activate()
```

#### Hitbox Properties

```gdscript
@export var faction: String = "neutral"              # Source faction
@export var damage_amount: float = 10.0              # Damage amount
@export var damage_type: DamageType = PHYSICAL       # Damage type
@export var source_node_path: NodePath = ^".."       # Path to source entity
@export var knockback_force: Vector2 = Vector2.ZERO  # Knockback vector
@export var knockback_duration: float = 0.2          # Knockback duration
@export var auto_activate: bool = false              # Auto-activate on ready
@export var activation_duration: float = 0.5         # How long hitbox stays active
```

#### Hitbox Activation

```gdscript
# Manual activation
hitbox.activate()

# Check if active
if hitbox.is_active():
    print("Hitbox is dealing damage!")

# Deactivate early
hitbox.deactivate()

# Get activation progress (0.0 to 1.0)
var progress := hitbox.get_activation_progress()
```

### Collision Filtering

The system supports faction-based damage filtering:

```gdscript
# Hurtbox configuration
hurtbox.faction = "player"
hurtbox.friendly_fire = false      # Don't damage other players
hurtbox.immune_factions = ["ally"] # Immune to allies

# Check compatibility
if hurtbox.can_take_damage_from_faction("enemy"):
    print("Can be damaged by enemies")
```

### Event Integration

All hitbox/hurtbox interactions publish EventBus events:

```gdscript
# Subscribe to combat events
EventBus.sub(EventTopics.COMBAT_HURTBOX_HIT, _on_hurtbox_hit)
EventBus.sub(EventTopics.COMBAT_HITBOX_ACTIVATED, _on_hitbox_activated)

func _on_hurtbox_hit(payload: Dictionary) -> void:
    # Analytics: hurtbox faction, hitbox faction, damage amount, positions
    print("Damage dealt: ", payload.damage_amount, " from ", payload.hitbox_faction, " to ", payload.hurtbox_faction)

func _on_hitbox_activated(payload: Dictionary) -> void:
    # Analytics: hitbox activated with damage info
    print("Hitbox activated: ", payload.damage_amount, " damage")
```

### Setup Examples

#### Player Hurtbox

```gdscript
# Player.gd
func _ready():
    # Add HealthComponent
    var health := HealthComponent.new()
    health.max_health = 100.0
    add_child(health)

    # Add HurtboxComponent
    var hurtbox := HurtboxComponent.new()
    hurtbox.faction = "player"
    hurtbox.friendly_fire = false
    add_child(hurtbox)

    # Connect to body (CircleShape2D)
    var shape := CircleShape2D.new()
    shape.radius = 16.0
    var collision := CollisionShape2D.new()
    collision.shape = shape
    hurtbox.add_child(collision)
```

#### Enemy Hitbox

```gdscript
# EnemyAttack.gd
func perform_attack():
    # Create hitbox for attack
    var hitbox := HitboxComponent.new()
    hitbox.faction = "enemy"
    hitbox.damage_amount = 15.0
    hitbox.activation_duration = 0.4
    hitbox.knockback_force = Vector2(50, -20)

    # Add collision shape
    var shape := RectangleShape2D.new()
    shape.size = Vector2(32, 16)
    var collision := CollisionShape2D.new()
    collision.shape = shape
    collision.position = Vector2(16, 0)  # Offset in front
    hitbox.add_child(collision)

    add_child(hitbox)
    hitbox.activate()

    # Clean up after attack
    await get_tree().create_timer(0.5).timeout
    hitbox.queue_free()
```

#### Projectile Hitbox

```gdscript
# Projectile.gd
func _ready():
    var hitbox := HitboxComponent.new()
    hitbox.faction = "enemy"
    hitbox.damage_amount = 20.0
    hitbox.activation_duration = 10.0  # Active while projectile exists
    hitbox.auto_activate = true

    # Add collision shape
    var shape := CircleShape2D.new()
    shape.radius = 4.0
    var collision := CollisionShape2D.new()
    collision.shape = shape
    hitbox.add_child(collision)

    add_child(hitbox)
```

### Best Practices

#### Hurtbox Setup
- Attach hurtboxes to entities that have HealthComponent
- Use appropriate collision shapes (circle for characters, rectangles for objects)
- Configure faction settings for proper damage filtering
- Connect to signals for visual/audio feedback

#### Hitbox Setup
- Attach hitboxes to weapons, projectiles, or attack areas
- Set appropriate activation duration for attack timing
- Configure damage and knockback for attack strength
- Use auto-activate for persistent hitboxes (projectiles)

#### Performance
- Hurtboxes monitor, hitboxes are monitorable
- Only active hitboxes deal damage
- Damage tracking prevents multi-hits per activation
- EventBus events include position data for spatial queries

#### Debugging
- Use EventBus inspector to monitor hitbox/hurtbox events
- Check faction compatibility with `can_take_damage_from_faction()`
- Verify collision shapes don't overlap unintentionally
- Monitor activation states with `is_active()`

## KnockbackResolver

The KnockbackResolver applies physics-based knockback to entities when they take damage. It supports multiple knockback modes and respects entity mass.

### Knockback Modes

- **IMPULSE**: Single physics impulse with drag decay
- **FORCE**: Continuous force application over time
- **VELOCITY_SET**: Direct velocity assignment with decay
- **SPRING**: Spring-like physics with damping

```gdscript
# Attach to CharacterBody2D
var knockback := KnockbackResolver.new()
knockback.mode = KnockbackResolver.KnockbackMode.IMPULSE
knockback.mass_override = 2.0  # Heavier entity
knockback.max_knockback_speed = 800.0
entity.add_child(knockback)

# Apply knockback
knockback.apply_knockback(Vector2(300, -150), 0.5)  # Force, duration
```

### Configuration

```gdscript
@export var mode: KnockbackMode = IMPULSE
@export var mass_override: float = 0.0         # 0 = use physics mass
@export var max_knockback_speed: float = 1000.0
@export var drag_coefficient: float = 0.1
@export var gravity_multiplier: float = 1.0    # Gravity during knockback
@export var air_control_modifier: float = 0.5  # Air control during knockback
```

### Advanced Features

```gdscript
# Check knockback state
if knockback.is_knockback_active():
    var progress = knockback.get_knockback_progress()  # 0.0 to 1.0
    var velocity = knockback.get_knockback_velocity()

# Stop knockback early
knockback.stop_knockback()

# Dynamic configuration
knockback.set_knockback_mode(KnockbackResolver.KnockbackMode.SPRING)
knockback.set_mass_override(5.0)  # Make entity heavier
```

### Integration with Damage

Knockback is automatically applied when `DamageInfo` contains knockback data:

```gdscript
var damage := DamageInfo.create_damage(25.0, DamageInfo.DamageType.PHYSICAL)
damage = damage.with_knockback(Vector2(200, -100), 0.3)

# HurtboxComponent automatically applies knockback via KnockbackResolver
health_component.take_damage(damage)
```

## StatusEffectManager

The StatusEffectManager handles DoT effects, buffs, debuffs, and other temporary status modifications with stacking rules and timers.

### Status Effects

Each status effect has properties:
- **Duration**: How long the effect lasts
- **Stacks**: Number of effect instances (for stacking)
- **Tick Interval**: For damage-over-time effects
- **Metadata**: Custom effect parameters

```gdscript
# Attach to entity
var status_manager := StatusEffectManager.new()
entity.add_child(status_manager)

# Apply effects
var poison = StatusEffectManager.create_dot_effect(5.0, 2.0, 10.0)  # 5 dmg every 2s for 10s
status_manager.apply_effect(poison)

var speed_boost = StatusEffectManager.create_speed_buff(1.5, 8.0)  # 50% speed for 8s
status_manager.apply_effect(speed_boost)
```

### Built-in Effect Types

#### Damage Over Time (DoT)
```gdscript
var burn = StatusEffectManager.create_dot_effect(8.0, 1.0, 6.0)  # 8 dmg/sec for 6s
burn.name = "Burning"
burn.description = "Deals fire damage over time"
status_manager.apply_effect(burn)
```

#### Movement Modifiers
```gdscript
var slow = StatusEffectManager.create_speed_debuff(0.6, 5.0)  # 40% slow for 5s
var haste = StatusEffectManager.create_speed_buff(1.8, 10.0)   # 80% speed for 10s
```

#### Combat Modifiers
```gdscript
var damage_up = StatusEffectManager.create_damage_buff(1.25, 15.0)     # 25% more damage
var damage_down = StatusEffectManager.create_damage_reduction_buff(0.8, 10.0)  # 20% less damage
```

#### Special Effects
```gdscript
var stun = StatusEffectManager.create_stun_effect(2.0)           # Can't move/act for 2s
var invuln = StatusEffectManager.create_invulnerability_effect(3.0)  # Immune to damage for 3s
```

### Stacking Rules

Effects can stack with configurable rules:

```gdscript
# Create stackable effect
var effect = StatusEffectManager.StatusEffect.new("custom_buff", "Custom Buff")
effect.max_stacks = 5
effect.duration = 10.0
effect.metadata["power"] = 10

# Applying multiple times increases stacks
status_manager.apply_effect(effect)  # Stack 1
status_manager.apply_effect(effect)  # Stack 2 (refreshes duration)
```

### Movement System Integration

Status effects provide hooks for movement/ability systems:

```gdscript
# Get movement modifiers
var speed_modifier = status_manager.get_movement_speed_modifier()  # e.g., 0.6 for slowed
var damage_modifier = status_manager.get_damage_dealt_modifier()   # e.g., 1.25 for buffed

# Check special states
if status_manager.is_stunned():
    disable_movement_and_actions()

if status_manager.is_invulnerable():
    immune_to_damage = true
```

### Custom Effects

Create custom status effects with callbacks:

```gdscript
var effect = StatusEffectManager.StatusEffect.new("custom", "Custom Effect")
effect.duration = 5.0
effect.on_apply = func(effect_instance):
    print("Effect applied!")
    # Custom apply logic

effect.on_tick = func(effect_instance):
    # Called every tick_interval (if set)
    apply_custom_effect()

effect.on_expire = func(effect_instance):
    print("Effect expired!")
    # Cleanup logic

status_manager.apply_effect(effect)
```

### Effect Management

```gdscript
# Check effects
if status_manager.has_effect("poison"):
    var stacks = status_manager.get_effect_stacks("poison")

# Remove effects
status_manager.remove_effect("speed_buff")

# Clear all
status_manager.clear_all_effects()

# Get all active effects
var active_effects = status_manager.get_active_effects()
for effect in active_effects:
    print("Active: ", effect.name, " (", effect.current_stacks, " stacks)")
```

### EventBus Integration

Status effects emit detailed analytics:

```gdscript
# Subscribe to status events
EventBus.sub("combat/status_effect_applied", _on_status_applied)
EventBus.sub("combat/status_effect_expired", _on_status_expired)

func _on_status_applied(payload: Dictionary):
    # payload: {effect_id, effect_name, stacks, duration, entity_position, timestamp_ms}
    show_status_effect_ui(payload.effect_name, payload.stacks)

func _on_status_expired(payload: Dictionary):
    hide_status_effect_ui(payload.effect_id)
```

### Deterministic RNG Usage

For effects that rely on chance (e.g., proc rates), use the RNGService:

```gdscript
effect.on_tick = func(effect_instance):
    if RNGService.chance(0.3):  # 30% chance each tick
        apply_proc_effect()
```

## Integration Examples

### Complete Combat Entity Setup

```gdscript
# Player setup with full combat system
func _ready():
    # Health management
    var health = HealthComponent.new()
    health.max_health = 100.0
    add_child(health)

    # Status effects
    var status = StatusEffectManager.new()
    add_child(status)

    # Knockback physics
    var knockback = KnockbackResolver.new()
    knockback.mode = KnockbackResolver.KnockbackMode.IMPULSE
    add_child(knockback)

    # Hurtbox for taking damage
    var hurtbox = HurtboxComponent.new()
    hurtbox.faction = "player"
    add_child(hurtbox)

# Enemy setup
func _ready():
    # Similar setup but with enemy faction
    var health = HealthComponent.new()
    health.max_health = 50.0
    add_child(health)

    var hurtbox = HurtboxComponent.new()
    hurtbox.faction = "enemy"
    add_child(hurtbox)

    # Hitbox for dealing damage
    var hitbox = HitboxComponent.new()
    hitbox.faction = "enemy"
    hitbox.damage_amount = 15.0
    hitbox.activation_duration = 0.3
    add_child(hitbox)

    # Connect hitbox to attack animation
    hitbox.activate()  # When enemy attacks
```

### Movement System Integration

```gdscript
func _physics_process(delta):
    # Get base movement speed
    var base_speed = 200.0

    # Apply status effect modifiers
    var speed_modifier = 1.0
    if has_node("StatusEffectManager"):
        speed_modifier = $StatusEffectManager.get_movement_speed_modifier()

    # Check stun status
    if has_node("StatusEffectManager") and $StatusEffectManager.is_stunned():
        velocity = Vector2.ZERO
        return

    # Apply modified speed
    velocity = input_vector * base_speed * speed_modifier
    move_and_slide()
```

### Ability System Integration

```gdscript
func can_use_ability(ability_name: String) -> bool:
    # Check stun status
    if has_node("StatusEffectManager") and $StatusEffectManager.is_stunned():
        return false

    # Check other ability-specific conditions
    return true

func get_ability_damage_multiplier() -> float:
    if has_node("StatusEffectManager"):
        return $StatusEffectManager.get_damage_dealt_modifier()
    return 1.0
```

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

## Death Handling & Entity Lifecycle

The DeathHandler component manages the complete entity death lifecycle - from death detection through animation, loot drops, and respawning.

### DeathHandler Component

Handles entity death with configurable behavior for animations, loot, and respawning.

```gdscript
# Attach to entities that can die
var death_handler := DeathHandler.new()
death_handler.death_animation_scene = preload("res://effects/DeathExplosion.tscn")
death_handler.auto_drop_loot = true
death_handler.respawn_enabled = true
death_handler.respawn_delay = 3.0
death_handler.respawn_position = Vector2(100, 100)
entity.add_child(death_handler)

# Connect to death events
death_handler.death_started.connect(_on_entity_death_started)
death_handler.loot_dropped.connect(_on_loot_dropped)
death_handler.respawn_completed.connect(_on_entity_respawned)
```

#### Death Sequence Flow

1. **Death Detection**: HealthComponent emits `died` signal
2. **Death Started**: DeathHandler begins death sequence
3. **Animation**: Optional death animation plays
4. **Loot Drop**: Items spawn based on loot table or defaults
5. **Entity Cleanup**: Disable physics, hide visuals, disable hurtboxes
6. **Respawn**: After delay, reset and reposition entity (optional)

#### DeathHandler Properties

```gdscript
@export var death_animation_scene: PackedScene      # Optional death effect
@export var death_animation_duration: float = 2.0   # Animation length
@export var auto_drop_loot: bool = true             # Enable loot drops
@export var loot_table_path: String = ""            # Loot table resource path
@export var respawn_enabled: bool = false           # Enable respawning
@export var respawn_delay: float = 3.0             # Time before respawn
@export var respawn_position: Vector2 = Vector2.ZERO # Respawn location
@export var emit_analytics: bool = true             # Analytics events
@export var emit_debug_info: bool = false           # Debug logging
```

#### Death Events

```gdscript
# Death lifecycle events
death_handler.death_started.connect(func(entity, death_info):
    # Entity just died
    play_death_sound()
    screen_shake()
)

death_handler.death_animation_started.connect(func(entity, animation_name):
    # Death animation began
    print("Playing death animation: ", animation_name)
)

death_handler.loot_dropped.connect(func(entity, loot_items):
    # Loot items spawned
    for item in loot_items:
        add_loot_to_world(item, entity.global_position)
)

death_handler.respawn_started.connect(func(entity, respawn_pos):
    # Respawn countdown began
    show_respawn_timer(respawn_pos)
)

death_handler.respawn_completed.connect(func(entity, respawn_pos):
    # Entity respawned
    play_respawn_effect(respawn_pos)
    reset_camera_target(entity)
)
```

### Loot System Integration

The DeathHandler supports loot drops through the Items & Economy system.

#### Loot Table Integration

```gdscript
# Use a loot table for drops
death_handler.loot_table_path = "res://data/loot_tables/enemy_basic.tres"

# Loot table would be a resource with weighted item drops
# When entity dies, DeathHandler calls loot table to generate drops
```

#### Default Loot Generation

```gdscript
# Override default loot generation
func _generate_default_loot(entity: Node) -> Array:
    # Generate loot based on entity type, level, etc.
    match entity.enemy_type:
        "goblin":
            return [{"item_id": "gold_coin", "quantity": 5}]
        "orc":
            return [
                {"item_id": "gold_coin", "quantity": 15},
                {"item_id": "rusty_sword", "quantity": 1}
            ]
    return []
```

### Respawn System

Configurable respawning with FlowManager integration for scene transitions.

#### Basic Respawning

```gdscript
# Simple respawn at fixed position
death_handler.set_respawn_enabled(true, 3.0, checkpoint_position)
```

#### Scene-Based Respawning

```gdscript
# Respawn with scene transition
death_handler.respawn_scene_transition = true
death_handler.respawn_transition_name = "fade_to_black"

# This would integrate with FlowManager for proper scene reloading
```

#### Respawn Callbacks

```gdscript
func _on_entity_respawned(entity: Node, respawn_position: Vector2) -> void:
    # Custom respawn logic
    entity.velocity = Vector2.ZERO
    entity.play_idle_animation()

    # Notify other systems
    EventBus.pub(EventTopics.PLAYER_RESPAWNED, {
        "position": respawn_position,
        "entity": entity
    })
```

### Analytics & Debugging

Death events are tracked through EventBus for analytics and debugging.

#### Death Analytics Events

```gdscript
# Subscribe to death analytics
EventBus.sub("combat/entity_death", func(payload):
    # payload: {entity_name, entity_type, faction, position, damage_source, damage_type, timestamp_ms}
    Analytics.track_event("entity_death", payload)
    print("Entity died: ", payload.entity_name, " by ", payload.damage_source)
)

# Subscribe to lifecycle events for debugging
EventBus.sub("combat/status_effect_applied", _on_status_applied)
EventBus.sub("combat/hurtbox_hit", _on_damage_taken)
EventBus.sub("combat/entity_death", _on_entity_death)
```

#### Debug Information

```gdscript
# Enable debug logging
death_handler.emit_debug_info = true

# Will log:
# "DeathHandler: Starting death animation for Enemy1"
# "DeathHandler: Dropped 3 loot items for Enemy1"
# "DeathHandler: Starting respawn for Enemy1 in 3 seconds"
# "DeathHandler: Performing respawn for Enemy1"
```

### Entity State Management

DeathHandler manages entity state transitions between alive, dying, and dead.

#### State Transitions

```gdscript
enum EntityState { ALIVE, DYING, DEAD, RESPAWNING }

func get_entity_state(entity: Node) -> EntityState:
    var death_handler = entity.get_node_or_null("DeathHandler")
    if not death_handler:
        return EntityState.ALIVE

    if death_handler.is_entity_dying():
        return EntityState.DYING

    if not entity.visible:  # Dead entities are hidden
        if death_handler.respawn_enabled:
            return EntityState.RESPAWNING
        else:
            return EntityState.DEAD

    return EntityState.ALIVE
```

#### State-Based Behavior

```gdscript
func update_entity_ai(entity: Node) -> void:
    var state = get_entity_state(entity)

    match state:
        EntityState.ALIVE:
            # Normal AI behavior
            process_ai(entity)
        EntityState.DYING:
            # Death animation in progress
            pass
        EntityState.DEAD:
            # Entity permanently dead
            remove_from_ai_system(entity)
        EntityState.RESPAWNING:
            # Waiting for respawn
            show_respawn_indicator(entity)
```

### FlowManager Integration

For scene-based respawning and game over handling.

#### Scene Respawning

```gdscript
# When player dies, transition to game over scene
func _on_player_died(source: Node, damage_info: DamageInfo) -> void:
    if source == player_entity:
        # Player died - go to game over
        FlowManager.push_scene("res://scenes/GameOver.tscn", {
            "death_cause": damage_info.source_name,
            "final_score": game_score
        })
```

#### Checkpoint Respawning

```gdscript
# Respawn at last checkpoint
func _on_player_respawned(entity: Node, respawn_position: Vector2) -> void:
    # Update checkpoint system
    if Engine.has_singleton("World"):
        var world = Engine.get_singleton("World")
        world.call("update_checkpoint", respawn_position)

    # Reset camera to respawn position
    camera.global_position = respawn_position
    camera.follow_target = entity
```

### Lifecycle Expectations

#### For Combat System Consumers

**Systems that consume combat events should expect:**

1. **Event Ordering**: Events fire in sequence (damage → death → respawn)
2. **State Consistency**: Entity state is consistent during event callbacks
3. **Thread Safety**: Events are emitted on main thread during physics process
4. **Null Safety**: Entity references may become invalid after death

#### For DeathHandler Implementers

**When implementing custom death behavior:**

1. **Call Super**: Always call parent `_complete_death_sequence()` for cleanup
2. **State Management**: Use `_set_entity_dead_state()` for consistent state
3. **Event Emission**: Emit signals before state changes for UI responsiveness
4. **Resource Cleanup**: Clean up effects, timers, and references on death

#### Example Custom DeathHandler

```gdscript
class_name BossDeathHandler extends DeathHandler

func _complete_death_sequence(entity: Node, death_info: Dictionary) -> void:
    # Custom boss death behavior
    play_boss_defeat_music()
    spawn_victory_particles(entity.global_position)
    unlock_next_level()

    # Call parent for standard cleanup
    super._complete_death_sequence(entity, death_info)

func _generate_default_loot(entity: Node) -> Array:
    # Boss drops special loot
    return [
        {"item_id": "boss_soul", "quantity": 1},
        {"item_id": "gold_coin", "quantity": 100},
        {"item_id": "legendary_sword", "quantity": 1}
    ]
```

This death handling system provides comprehensive lifecycle management for entities, from death detection through respawning, with full integration with other game systems.

## FactionManager

The FactionManager singleton manages faction relationships and enables team-based gameplay mechanics.

### Faction Relationships

```gdscript
# Basic faction setup
FactionManager.register_faction("undead")
FactionManager.register_faction("holy")

# Set relationships
FactionManager.set_relationship("undead", "holy", FactionManager.Relationship.ENEMY)
FactionManager.set_relationship("holy", "undead", FactionManager.Relationship.ENEMY)

# Create alliances
FactionManager.create_faction_group(["elves", "dwarves", "humans"], "alliance")

# Check relationships
if FactionManager.can_damage("undead", "holy"):
    print("Undead can damage holy units")
```

### Built-in Factions

- **neutral**: Default faction for environment objects
- **player**: Player character and allies
- **enemy**: Standard enemies
- **ally**: NPC allies
- **environment**: Environmental hazards

### Relationship Types

- **NEUTRAL**: Can damage each other, no special relationship
- **ALLY**: Cannot damage each other
- **ENEMY**: Can damage each other (default for player vs enemy)
- **IGNORE**: Cannot interact at all

### Advanced Features

```gdscript
# Declare war (makes allies enemies too)
FactionManager.declare_war("orcs", "elves")

# Get faction information
var enemies = FactionManager.get_enemy_factions("player")
var allies = FactionManager.get_allied_factions("elves")

# Debug faction relationships
FactionManager.debug_print_relationships()
```

### Integration with Combat

The FactionManager automatically integrates with hurtboxes and hitboxes:

```gdscript
# Hurtbox faction filtering
hurtbox.faction = "player"
hurtbox.friendly_fire = false  # Won't take damage from other players

# Hitbox faction checking
if hitbox.can_damage_faction("enemy"):
    # Can damage enemies
    hitbox.activate()
```

## BaseProjectile System

Configurable projectile system with multiple motion types, designed for object pooling and extensibility.

### Motion Types

- **LINEAR**: Straight line movement
- **HOMING**: Seeks target with configurable strength
- **ARC**: Parabolic arc trajectory
- **WAVE**: Sinusoidal wave motion
- **BOUNCE**: Bounces off surfaces
- **SPIRAL**: Spiral motion pattern

### Basic Usage

```gdscript
# Create and configure projectile
var projectile = BaseProjectile.new()
projectile.motion_type = BaseProjectile.MotionType.HOMING
projectile.speed = 400.0
projectile.damage_amount = 25.0
projectile.faction = "player"
projectile.homing_strength = 2.0

# Launch projectile
projectile.launch(Vector2.RIGHT, 400.0, target_enemy)
add_child(projectile)
```

### Motion-Specific Configuration

```gdscript
# Homing projectile
projectile.motion_type = BaseProjectile.MotionType.HOMING
projectile.homing_strength = 1.5  # How aggressively it turns

# Arc projectile
projectile.motion_type = BaseProjectile.MotionType.ARC
projectile.arc_height = 80.0  # Height of the arc

# Wave projectile
projectile.motion_type = BaseProjectile.MotionType.WAVE
projectile.wave_frequency = 3.0
projectile.wave_amplitude = 30.0

# Bouncing projectile
projectile.motion_type = BaseProjectile.MotionType.BOUNCE
projectile.bounce_count = 5
```

### Advanced Features

```gdscript
# Piercing projectiles
projectile.pierce_count = 3  # Hits up to 3 enemies

# Knockback on hit
projectile.knockback_force = Vector2(200, -150)

# Visual effects
projectile.trail_effect = preload("res://effects/ProjectileTrail.tscn")
projectile.impact_effect = preload("res://effects/ImpactExplosion.tscn")

# Dynamic configuration
projectile.set_damage(50.0, DamageInfo.DamageType.FIRE)
projectile.set_faction("enemy")
projectile.set_knockback(Vector2(300, -200))
```

### Object Pooling Integration

```gdscript
# Projectile pool manager
class ProjectilePool:
    var pool: Array[BaseProjectile] = []
    var scene: PackedScene

    func get_projectile() -> BaseProjectile:
        if pool.is_empty():
            return scene.instantiate()
        else:
            return pool.pop_back()

    func return_projectile(projectile: BaseProjectile) -> void:
        projectile.hide()
        pool.append(projectile)

# Usage
var pool = ProjectilePool.new()
pool.scene = preload("res://Combat/BaseProjectile.tscn")

var projectile = pool.get_projectile()
projectile.launch(direction)
# When projectile.destroy() is called, return to pool instead of queue_free
```

### Analytics Integration

Projectiles automatically emit EventBus events for analytics:

```gdscript
# Projectile fired
EventBus.sub("combat/projectile_fired", func(payload):
    Analytics.track_event("projectile_fired", payload)
)

# Projectile hit
EventBus.sub("combat/projectile_hit", func(payload):
    Analytics.track_event("projectile_hit", payload)
)
```

### Extending Projectiles

```gdscript
class FireballProjectile extends BaseProjectile:
    func _ready():
        super._ready()
        # Add fire-specific setup
        damage_type = DamageInfo.DamageType.FIRE
        # Add particle effects, etc.

    func on_hit(target: Node):
        super.on_hit(target)
        # Add fire-specific effects
        target.apply_burn_effect()
        create_fire_explosion()
```

### Performance Considerations

- **Object Pooling**: Essential for projectile-heavy games
- **Lifetime Management**: Automatic cleanup prevents memory leaks
- **Collision Layers**: Use appropriate collision masks for performance
- **Motion Complexity**: Simpler motion types perform better
- **Analytics Throttling**: Consider throttling events for high-fire-rate weapons

This faction and projectile system provides the foundation for complex combat scenarios with team-based gameplay and varied projectile behaviors.
