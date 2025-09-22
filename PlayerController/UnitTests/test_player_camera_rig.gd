extends "res://addons/gut/test.gd"

const RigScriptPath: String = "res://PlayerController/Camera/PlayerCameraRig.gd"

class VelocityNode extends Node2D:
    var velocity: Vector2 = Vector2.ZERO

    func get_motion_velocity() -> Vector2:
        return velocity

class FlowManagerStub extends Node:
    signal about_to_change(scene_path: String, entry: Variant)
    signal scene_changed(scene_path: String, entry: Variant)

var rig: PlayerCameraRig
var camera: Camera2D
var target: VelocityNode
var flow_manager: FlowManagerStub

func before_each() -> void:
    rig = load(RigScriptPath).new()
    rig.name = "PlayerCameraRig"
    rig.smoothing_enabled = false
    camera = Camera2D.new()
    camera.name = "Camera2D"
    target = VelocityNode.new()
    target.name = "Target"
    flow_manager = FlowManagerStub.new()
    flow_manager.name = "FlowManagerStub"
    rig.add_child(camera)
    get_tree().root.add_child(flow_manager)
    get_tree().root.add_child(target)
    await get_tree().process_frame
    rig.target_path = target.get_path()
    rig.flow_manager_path = flow_manager.get_path()
    get_tree().root.add_child(rig)
    await rig.ready

func after_each() -> void:
    for node in [rig, target, flow_manager]:
        if is_instance_valid(node):
            node.queue_free()
    await get_tree().process_frame

func test_camera_follows_target_position() -> void:
    target.global_position = Vector2(120, -40)
    rig._physics_process(0.016)
    assert_eq(rig.global_position, target.global_position)

func test_lookahead_uses_target_velocity() -> void:
    target.global_position = Vector2.ZERO
    rig.lookahead_enabled = true
    rig.lookahead_distance = Vector2(80, 40)
    target.velocity = Vector2(80, 0)
    rig._physics_process(0.016)
    assert_eq(rig.global_position, Vector2(80, 0))

func test_cutscene_suspend_and_resume_follow() -> void:
    var cutscene_target := Node2D.new()
    cutscene_target.name = "CutsceneTarget"
    get_tree().root.add_child(cutscene_target)
    await cutscene_target.ready
    cutscene_target.global_position = Vector2(200, 200)
    var last_states: Array = []
    var suspension_states: Array = []
    rig.cutscene_mode_changed.connect(func(enabled: bool): last_states.append(enabled))
    rig.follow_suspended_changed.connect(func(suspended: bool): suspension_states.append(suspended))
    rig.begin_cutscene(cutscene_target, suspend_follow: true)
    rig._physics_process(0.016)
    assert_eq(rig.global_position, cutscene_target.global_position)
    assert_true(suspension_states.has(true))
    rig.end_cutscene()
    assert_true(last_states.has(true))
    assert_true(last_states.has(false))
    assert_true(suspension_states.has(false))
    cutscene_target.queue_free()

func test_flow_manager_suspends_follow_on_transition() -> void:
    target.global_position = Vector2.ZERO
    rig._physics_process(0.016)
    flow_manager.about_to_change.emit("res://dummy.tscn", null)
    target.global_position = Vector2(500, 500)
    rig._physics_process(0.016)
    assert_eq(rig.global_position, Vector2.ZERO)
    flow_manager.scene_changed.emit("res://dummy.tscn", null)
    rig._physics_process(0.016)
    assert_eq(rig.global_position, target.global_position)
*** End Patch
