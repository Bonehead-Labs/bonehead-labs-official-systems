class_name PatrolState
extends FSMState

## State for enemy patrol behavior - moves between waypoints.

var _enemy: EnemyBase
var _config: EnemyConfig
var _waypoints: Array[Vector2] = []
var _current_waypoint_index: int = 0
var _waypoint_tolerance: float = 10.0
var _patrol_timer: float = 0.0
var _wait_time: float = 2.0

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
    super.setup(state_machine, state_owner, state_context)
    _enemy = state_context[&"enemy"]
    _config = state_context[&"config"]

    if _config:
        _waypoint_tolerance = _config.waypoint_tolerance

    # Initialize waypoints if not provided
    if _waypoints.is_empty():
        _setup_default_waypoints()

func _setup_default_waypoints() -> void:
    # Create a simple patrol pattern around spawn position
    var center = _enemy.global_position
    var radius = 100.0

    _waypoints = [
        center + Vector2(radius, 0),
        center + Vector2(0, radius),
        center + Vector2(-radius, 0),
        center + Vector2(0, -radius)
    ]

func enter(_payload: Dictionary[StringName, Variant] = {}) -> void:
    _current_waypoint_index = 0
    _patrol_timer = 0.0

    if not _waypoints.is_empty():
        _move_to_next_waypoint()

func update(delta: float) -> void:
    if _waypoints.is_empty():
        return

    # Check if reached current waypoint
    var current_waypoint = _waypoints[_current_waypoint_index]
    var distance_to_waypoint = _enemy.global_position.distance_to(current_waypoint)

    if distance_to_waypoint <= _waypoint_tolerance:
        # Reached waypoint, wait or move to next
        _patrol_timer += delta
        _enemy.stop_moving()

        if _patrol_timer >= _wait_time:
            _move_to_next_waypoint()
    else:
        # Still moving toward waypoint
        _enemy.move_toward(current_waypoint, _config.patrol_speed if _config else 50.0)
        _enemy.flip_sprite_to_face(current_waypoint)

func physics_update(delta: float) -> void:
    # Handle alert transitions
    if _enemy.is_alerted():
        machine.transition_to(&"chase", {&"reason": &"alerted"})

func handle_event(event: StringName, data: Variant = null) -> void:
    match event:
        &"alerted":
            machine.transition_to(&"chase", {&"reason": &"alerted"})
        &"damaged":
            machine.transition_to(&"chase", {&"reason": &"damaged"})

func _move_to_next_waypoint() -> void:
    _current_waypoint_index = (_current_waypoint_index + 1) % _waypoints.size()
    _patrol_timer = 0.0

    # Emit event for analytics
    emit_event(&"waypoint_reached", {
        &"waypoint_index": _current_waypoint_index,
        &"waypoint_position": _waypoints[_current_waypoint_index]
    })

## Set custom waypoints for patrol
func set_waypoints(waypoints: Array[Vector2]) -> void:
    _waypoints = waypoints.duplicate()
    _current_waypoint_index = 0

## Add a waypoint to the patrol path
func add_waypoint(position: Vector2) -> void:
    _waypoints.append(position)

## Clear all waypoints
func clear_waypoints() -> void:
    _waypoints.clear()
    _current_waypoint_index = 0
