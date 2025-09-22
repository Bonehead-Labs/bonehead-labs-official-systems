class_name FlowAsyncLoader
extends RefCounted

enum LoadStatus {
    IDLE,
    LOADING,
    LOADED,
    FAILED,
    CANCELLED
}

class LoadHandle extends RefCounted:
    var scene_path: String
    var status: LoadStatus = LoadStatus.IDLE
    var request_id: int = -1
    var progress: float = 0.0
    var error: Error = OK
    var result: PackedScene = null
    var seed_snapshot: int = 0
    var created_ms: int
    var metadata: Dictionary

    func _init(scene_path: String, metadata: Dictionary = {}) -> void:
        self.scene_path = scene_path
        self.metadata = metadata.duplicate(true)
        self.created_ms = Time.get_ticks_msec()

var _handles: Dictionary = {}

func start(scene_path: String, metadata: Dictionary = {}) -> LoadHandle:
    var handle := LoadHandle.new(scene_path, metadata)
    handle.seed_snapshot = _capture_seed(scene_path)
    var err := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
    if err != OK:
        handle.status = LoadStatus.FAILED
        handle.error = err
        return handle
    handle.request_id = ResourceLoader.get_threaded_request_id(scene_path)
    handle.status = LoadStatus.LOADING
    _handles[handle.request_id] = handle
    return handle

func poll(handle: LoadHandle) -> void:
    if handle == null or handle.status != LoadStatus.LOADING:
        return
    var progress: float = 0.0
    var status := ResourceLoader.load_threaded_get_status(handle.scene_path, progress)
    match status:
        ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
            handle.progress = progress
        ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
            handle.result = ResourceLoader.load_threaded_get(handle.scene_path)
            handle.progress = 1.0
            handle.status = LoadStatus.LOADED
            _handles.erase(handle.request_id)
        ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
            handle.status = LoadStatus.FAILED
            handle.error = ERR_CANT_OPEN
            _handles.erase(handle.request_id)
        ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
            handle.status = LoadStatus.FAILED
            handle.error = ERR_FILE_CANT_OPEN
            _handles.erase(handle.request_id)
        _:
            handle.status = LoadStatus.FAILED
            handle.error = ERR_UNAVAILABLE
            _handles.erase(handle.request_id)

func cancel(handle: LoadHandle) -> void:
    if handle == null or handle.status != LoadStatus.LOADING:
        return
    ResourceLoader.load_threaded_cancel(handle.scene_path)
    handle.status = LoadStatus.CANCELLED
    _handles.erase(handle.request_id)

func is_active(handle: LoadHandle) -> bool:
    return handle != null and handle.status == LoadStatus.LOADING

func has_pending_requests() -> bool:
    return not _handles.is_empty()

func clear() -> void:
    for id in _handles.keys():
        var handle: LoadHandle = _handles[id]
        ResourceLoader.load_threaded_cancel(handle.scene_path)
        handle.status = LoadStatus.CANCELLED
    _handles.clear()

func _capture_seed(scene_path: String) -> int:
    if not Engine.has_singleton("RNGService"):
        return 0
    var rng_service := Engine.get_singleton("RNGService")
    if rng_service == null:
        return 0
    if rng_service.has_method("snapshot_seed"):
        return int(rng_service.snapshot_seed(&"scene_flow", scene_path))
    if rng_service.has_method("get_seed"):
        return int(rng_service.get_seed())
    return 0
