extends Node
class_name CheckpointManager

## Singleton checkpoint manager with SaveService integration.

var _checkpoints: Array[Dictionary] = []
var _current_checkpoint: Dictionary = {}

signal checkpoint_registered(checkpoint_id: String, data: Dictionary)
signal checkpoint_activated(checkpoint_id: String, data: Dictionary)
signal checkpoint_loaded(checkpoint_id: String, data: Dictionary)

func register_checkpoint(checkpoint_id: String, position: Vector2, data: Dictionary = {}) -> bool:
    if checkpoint_id.is_empty():
        push_warning("CheckpointManager.register_checkpoint: empty checkpoint_id")
        return false

    var checkpoint_data: Dictionary = {
        "id": checkpoint_id,
        "position": position,
        "data": data.duplicate(true),
        "timestamp_ms": Time.get_ticks_msec()
    }

    # Remove existing checkpoint with same ID
    for i in range(_checkpoints.size()):
        if _checkpoints[i].get("id") == checkpoint_id:
            _checkpoints.remove_at(i)
            break

    _checkpoints.append(checkpoint_data)
    checkpoint_registered.emit(checkpoint_id, checkpoint_data)

    if Engine.has_singleton("EventBus"):
        Engine.get_singleton("EventBus").call("pub", &"world/checkpoint_registered", {
            "checkpoint_id": checkpoint_id,
            "position": position,
            "data": data.duplicate(true)
        })

    return true

func activate_checkpoint(checkpoint_id: String) -> bool:
    if checkpoint_id.is_empty():
        return false

    for checkpoint_data in _checkpoints:
        if checkpoint_data.get("id") == checkpoint_id:
            _current_checkpoint = checkpoint_data.duplicate(true)
            checkpoint_activated.emit(checkpoint_id, _current_checkpoint)

            if Engine.has_singleton("EventBus"):
                Engine.get_singleton("EventBus").call("pub", &"world/checkpoint_activated", {
                    "checkpoint_id": checkpoint_id,
                    "position": checkpoint_data.get("position"),
                    "data": checkpoint_data.get("data", {}).duplicate(true)
                })

            return true

    return false

func get_current_checkpoint() -> Dictionary:
    return _current_checkpoint.duplicate(true)

func get_checkpoint(checkpoint_id: String) -> Dictionary:
    for checkpoint_data in _checkpoints:
        if checkpoint_data.get("id") == checkpoint_id:
            return checkpoint_data.duplicate(true)
    return {}

func list_checkpoints() -> Array[Dictionary]:
    return _checkpoints.duplicate(true)

func clear_checkpoint(checkpoint_id: String) -> bool:
    for i in range(_checkpoints.size()):
        if _checkpoints[i].get("id") == checkpoint_id:
            _checkpoints.remove_at(i)
            if _current_checkpoint.get("id") == checkpoint_id:
                _current_checkpoint.clear()
            return true
    return false

## SaveService integration
func save_data() -> Dictionary:
    var checkpoints_data: Array = []
    for checkpoint_data in _checkpoints:
        checkpoints_data.append({
            "id": checkpoint_data.get("id"),
            "position": checkpoint_data.get("position"),
            "data": checkpoint_data.get("data", {}),
            "timestamp_ms": checkpoint_data.get("timestamp_ms", 0)
        })

    return {
        "checkpoints": checkpoints_data,
        "current_checkpoint": _current_checkpoint.duplicate(true)
    }

func load_data(data: Dictionary) -> bool:
    _checkpoints.clear()

    var checkpoints_data: Array = data.get("checkpoints", [])
    for checkpoint_dict in checkpoints_data:
        var checkpoint_data: Dictionary = {
            "id": checkpoint_dict.get("id", ""),
            "position": checkpoint_dict.get("position", Vector2.ZERO),
            "data": checkpoint_dict.get("data", {}),
            "timestamp_ms": checkpoint_dict.get("timestamp_ms", 0)
        }
        _checkpoints.append(checkpoint_data)

    _current_checkpoint = data.get("current_checkpoint", {}).duplicate(true)

    if not _current_checkpoint.is_empty():
        checkpoint_loaded.emit(_current_checkpoint.get("id", ""), _current_checkpoint)

    return true
