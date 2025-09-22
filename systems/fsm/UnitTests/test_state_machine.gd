extends "res://addons/gut/test.gd"

const MachinePath: String = "res://systems/fsm/StateMachine.gd"
const IdleStateScript := preload("res://systems/fsm/states/IdleState.gd")
const MoveStateScript := preload("res://systems/fsm/states/MoveState.gd")

var machine: StateMachine

func before_each() -> void:
    machine = load(MachinePath).new()
    machine.name = "StateMachine"
    get_tree().root.add_child(machine)
    await machine.ready
    machine.register_state(StringName("idle"), IdleStateScript)
    machine.register_state(StringName("move"), MoveStateScript)
    machine.set_context({StringName("threshold"): 3} as Dictionary[StringName, Variant])

func after_each() -> void:
    if is_instance_valid(machine):
        machine.queue_free()
        await get_tree().process_frame

func test_transition_to_idle() -> void:
    assert_eq(machine.transition_to(StringName("idle")), OK)
    assert_eq(machine.get_current_state(), StringName("idle"))

func test_state_updates_trigger_transition() -> void:
    machine.transition_to(StringName("idle"))
    machine.update_state(0.0)
    machine.update_state(0.0)
    machine.update_state(0.0)
    assert_eq(machine.get_current_state(), StringName("move"))

func test_handle_event_moves_state() -> void:
    machine.transition_to(StringName("idle"))
    machine.handle_event(StringName("move_requested"))
    assert_eq(machine.get_current_state(), StringName("move"))

func test_state_events_emitted() -> void:
    var events: Array = []
    machine.state_event.connect(func(e: StringName, data: Variant): events.append({"event": e, "data": data}))
    machine.transition_to(StringName("idle"))
    machine.handle_event(StringName("move_requested"))
    machine.update_state(0.5)
    machine.update_state(0.6)
    assert_true(events.size() >= 2)
