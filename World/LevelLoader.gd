extends Node
class_name LevelLoader

## Helper for loading levels using FlowManager.

static func load_level(scene_path: String, payload: Dictionary = {}) -> bool:
    if not ResourceLoader.exists(scene_path):
        push_error("LevelLoader.load_level: scene does not exist: " + scene_path)
        return false

    if not Engine.has_singleton("FlowManager"):
        push_error("LevelLoader.load_level: FlowManager autoload not found")
        return false

    var flow_manager = Engine.get_singleton("FlowManager")

    # Emit diagnostic event
    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/level_load_started", {
            "scene_path": scene_path,
            "payload_keys": payload.keys()
        })

    # Use FlowManager to replace scene
    var result: bool = flow_manager.call("replace_scene", scene_path, payload)

    if not result:
        push_error("LevelLoader.load_level: failed to load level: " + scene_path)

        if Engine.has_singleton("EventBus"):
            Engine.get_singleton("EventBus").call("pub", &"world/level_load_failed", {
                "scene_path": scene_path,
                "reason": "flow_manager_replace_failed"
            })

        return false

    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/level_load_success", {
            "scene_path": scene_path,
            "payload_keys": payload.keys()
        })

    return true

static func push_level(scene_path: String, payload: Dictionary = {}) -> bool:
    if not ResourceLoader.exists(scene_path):
        push_error("LevelLoader.push_level: scene does not exist: " + scene_path)
        return false

    if not Engine.has_singleton("FlowManager"):
        push_error("LevelLoader.push_level: FlowManager autoload not found")
        return false

    var flow_manager = Engine.get_singleton("FlowManager")

    # Emit diagnostic event
    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/level_push_started", {
            "scene_path": scene_path,
            "payload_keys": payload.keys()
        })

    var result: bool = flow_manager.call("push_scene", scene_path, payload)

    if not result:
        push_error("LevelLoader.push_level: failed to push level: " + scene_path)

        if Engine.has_singleton("EventBus"):
            Engine.get_singleton("EventBus").call("pub", &"world/level_push_failed", {
                "scene_path": scene_path,
                "reason": "flow_manager_push_failed"
            })

        return false

    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/level_push_success", {
            "scene_path": scene_path,
            "payload_keys": payload.keys()
        })

    return true

static func pop_level() -> bool:
    if not Engine.has_singleton("FlowManager"):
        push_error("LevelLoader.pop_level: FlowManager autoload not found")
        return false

    var flow_manager = Engine.get_singleton("FlowManager")

    # Emit diagnostic event
    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/level_pop_started", {})

    var result: bool = flow_manager.call("pop_scene")

    if not result:
        push_error("LevelLoader.pop_level: failed to pop level")

        if Engine.has_singleton("EventBus"):
            Engine.get_singleton("EventBus").call("pub", &"world/level_pop_failed", {
                "reason": "flow_manager_pop_failed"
            })

        return false

    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/level_pop_success", {})

    return true

static func get_current_level() -> String:
    if not Engine.has_singleton("FlowManager"):
        return ""

    var flow_manager = Engine.get_singleton("FlowManager")
    var current_scene: String = flow_manager.call("peek_scene")
    return current_scene
