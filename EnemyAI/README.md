# Enemy AI (2D)

A comprehensive 2D enemy AI system built on top of the shared FSM toolkit, providing modular AI behavior for platformer and top-down games.

## Architecture

The Enemy AI system leverages the shared FSM (Finite State Machine) system from `systems/fsm/` to create flexible, data-driven enemy behavior.

### Core Components

- **`EnemyBase`**: Base class extending `CharacterBody2D` with FSM integration
- **`EnemyConfig`**: Resource for enemy stats and behavior parameters
- **State Classes**: Individual AI behaviors (PatrolState, ChaseState, etc.)

### Required Node Structure

Every enemy scene should have these nodes:

```
EnemyScene (EnemyBase)
├── CollisionShape2D (required)
├── AnimatedSprite2D (recommended)
├── PerceptionArea (Area2D - optional)
├── HitboxComponent (Area2D - optional)
└── StateMachine (auto-created)
    ├── HealthComponent (auto-created)
    ├── HurtboxComponent (auto-created)
    └── DeathHandler (auto-created)
```

## EnemyBase Class

The foundation for all enemies, providing:

- **FSM Integration**: State machine with context sharing
- **Component Management**: Auto-setup of health, hurtboxes, hitboxes, death handling
- **Alert System**: Perception and target tracking
- **Movement Helpers**: Acceleration-based movement with facing direction
- **Combat Integration**: Damage dealing/receiving through Combat system
- **Analytics**: Event emission for behavior tracking
- **Save/Load**: Basic persistence support

### Basic Setup

```gdscript
# Create enemy scene
var enemy = EnemyBase.new()
enemy.config = EnemyConfig.create_basic_enemy()
add_child(enemy)

# Connect to lifecycle events
enemy.spawned.connect(_on_enemy_spawned)
enemy.alerted.connect(_on_enemy_alerted)
enemy.defeated.connect(_on_enemy_defeated)
enemy.state_changed.connect(_on_enemy_state_changed)
```

### Configuration

```gdscript
# Create custom enemy configuration
var config = EnemyConfig.new()
config.max_health = 150.0
config.movement_speed = 90.0
config.attack_damage = 20.0
config.detection_range = 200.0
config.faction = "bandits"
config.emit_analytics = true

enemy.config = config
```

## State System

States are script-based classes extending `FSMState`. The EnemyBase provides context to states including references to itself, config, and components.

### Built-in States

#### PatrolState
- Moves between waypoints in a patrol pattern
- Waits at waypoints before continuing
- Transitions to chase when alerted

```gdscript
# Custom patrol with specific waypoints
var patrol_state = PatrolState.new()
patrol_state.set_waypoints([
    Vector2(100, 0),
    Vector2(200, 0),
    Vector2(200, 100),
    Vector2(100, 100)
])
```

#### ChaseState
- Pursues alerted targets
- Transitions to attack when in range
- Times out and returns to patrol if target lost
- Handles navigation path updates

```gdscript
# Customize chase behavior
var chase_state = ChaseState.new()
chase_state.set_max_chase_time(45.0)  # Chase for 45 seconds max
```

### Creating Custom States

```gdscript
class_name CustomAttackState
extends FSMState

var _enemy: EnemyBase
var _config: EnemyConfig
var _attack_timer: float = 0.0

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    super.setup(state_machine, state_owner, state_context)
    _enemy = state_context[&"enemy"]
    _config = state_context[&"config"]

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    _attack_timer = 0.0
    var target = payload.get(&"target")
    if target:
        _enemy.flip_sprite_to_face(target.global_position)
        _enemy.play_animation("attack")

func update(delta: float) -> void:
    _attack_timer += delta

    if _attack_timer >= (_config.attack_cooldown if _config else 1.5):
        # Attack complete, return to appropriate state
        if _enemy.is_alerted():
            machine.transition_to(&"chase")
        else:
            machine.transition_to(&"patrol")

func handle_event(event: StringName, data: Variant = null) -> void:
    if event == &"interrupted":
        machine.transition_to(&"stunned", {&"reason": &"attack_interrupted"})
```

### State Registration

```gdscript
# Register states with the enemy
enemy.get_state_machine().register_state(&"attack", CustomAttackState)
enemy.get_state_machine().register_state(&"stunned", StunnedState)
```

## Perception System

Enemies can detect targets through Area2D-based perception systems.

### Basic Perception Setup

```gdscript
# Add PerceptionArea as child of enemy
var perception = Area2D.new()
perception.name = "PerceptionArea"
var shape = CircleShape2D.new()
shape.radius = 150.0  # Detection range
var collision = CollisionShape2D.new()
collision.shape = shape
perception.add_child(collision)
enemy.add_child(perception)

# Configure collision layer/mask for player detection
perception.collision_layer = 0
perception.collision_mask = 1  # Player layer
```

### Advanced Perception (Field of View)

```gdscript
class_name PerceptionCone
extends Area2D

@export var view_angle: float = 90.0  # degrees
@export var view_distance: float = 200.0

func _ready() -> void:
    var shape = ConeShape2D.new()
    shape.height = view_distance
    shape.top_radius = 0.0
    shape.bottom_radius = view_distance * tan(deg_to_rad(view_angle/2))
    $CollisionShape2D.shape = shape

func can_see_target(target: Node2D) -> bool:
    var to_target = target.global_position - global_position
    var angle_to_target = rad_to_deg(to_target.angle())
    var facing_angle = rad_to_deg(get_parent().get_facing_direction().angle())

    var angle_diff = abs(angle_to_target - facing_angle)
    angle_diff = min(angle_diff, 360 - angle_diff)  # Handle wraparound

    return angle_diff <= view_angle/2 and to_target.length() <= view_distance
```

## Combat Integration

Enemies automatically integrate with the Combat system.

### Health and Damage

```gdscript
# Enemy automatically has HealthComponent
var health = enemy.get_health_component()
health.connect("health_changed", _on_enemy_health_changed)

# Deal damage to enemy
enemy.take_damage(25.0, player, "physical")
```

### Debug Visualization

Enable perception and FOV debug drawing via `EnemyConfig`:

```
config.debug_draw_perception = true
config.debug_draw_fov = true
```

The `EnemyBase` will draw detection radius and FOV wedge. This is editor- and build-safe and only draws when the flags are enabled.

## Navigation and Steering

When `EnemyConfig.use_navigation` is true (default), `EnemyBase` attaches a `NavigationAgent2D` and uses it in `move_toward()` to steer along navigable paths with avoidance.

```
config.use_navigation = true
config.path_update_interval = 0.35
```

`ChaseState` updates the target position periodically using `path_update_interval`. If navigation is disabled, movement falls back to direct steering toward the target.

### Tuning and Determinism

- Use `detection_range`, `field_of_view_angle`, and `alert_duration` to control perception.
- For tests that require determinism, keep timers (`path_update_interval`, patrol wait time) fixed and gate any randomness behind `RNGService` once available.


### Attack Implementation

```gdscript
# In attack state
func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
    var target = payload.get(&"target")
    if target and _enemy.can_attack_target(target):
        # Activate hitbox for damage
        var hitbox = _enemy.get_hitbox_component()
        hitbox.activate()

        # Create projectile attack
        var projectile = BaseProjectile.new()
        projectile.launch(target.global_position - _enemy.global_position)
        get_parent().add_child(projectile)
```

### Death Handling

```gdscript
enemy.defeated.connect(func(enemy, cause):
    match cause:
        "damage":
            # Regular defeat
            spawn_death_particles(enemy.global_position)
        "timeout":
            # Enemy despawned due to time limit
            fade_out_enemy(enemy)
)
```

## Analytics and Debugging

### Event Tracking

Enemies emit comprehensive analytics events:

```gdscript
# Subscribe to enemy events
EventBus.sub("enemy/spawned", func(payload):
    Analytics.track_event("enemy_spawned", payload)
)

EventBus.sub("enemy/alerted", func(payload):
    Analytics.track_event("enemy_alerted", payload)
)

EventBus.sub("enemy/defeated", func(payload):
    Analytics.track_event("enemy_defeated", payload)
)
```

### State Machine Debugging

```gdscript
enemy.state_changed.connect(func(enemy, old_state, new_state):
    print("Enemy ", enemy.name, " changed from ", old_state, " to ", new_state)
)
```

## Examples

### Basic Patrol Enemy

```gdscript
# Scene setup: EnemyBase + CollisionShape2D + AnimatedSprite2D
var enemy = preload("res://EnemyAI/BasicEnemy.tscn").instantiate()
enemy.config = EnemyConfig.create_basic_enemy()

# Add patrol waypoints
var patrol_state = PatrolState.new()
patrol_state.set_waypoints([
    enemy.global_position + Vector2(100, 0),
    enemy.global_position + Vector2(0, 100),
    enemy.global_position + Vector2(-100, 0),
    enemy.global_position + Vector2(0, -100)
])

enemy.get_state_machine().register_state(&"patrol", patrol_state)
add_child(enemy)
```

### Ranged Enemy

```gdscript
class_name RangedEnemy
extends EnemyBase

func _setup_components() -> void:
    super._setup_components()

    # Add projectile weapon
    var weapon = ProjectileWeapon.new()
    weapon.projectile_scene = preload("res://Combat/BaseProjectile.tscn")
    weapon.fire_rate = 1.0
    add_child(weapon)
```

## Best Practices

### Performance
- Use object pooling for frequently spawned enemies
- Limit perception area sizes based on performance budget
- Disable analytics in release builds if not needed

### Design
- Keep states focused on single responsibilities
- Use config resources for balance tuning
- Test state transitions thoroughly

### Debugging
- Enable analytics events for behavior tracking
- Use state change signals for visual debugging
- Implement debug drawing for perception cones and waypoints

## Integration with Other Systems

### SaveService
Enemies support basic save/load through `save_data()` and `load_data()` methods.

### FlowManager
Enemies can integrate with scene transitions and checkpoints.

### Items & Economy
Enemies can drop loot through the DeathHandler component.

This Enemy AI system provides a flexible foundation for creating engaging enemy behavior while maintaining clean separation of concerns and easy extensibility.
