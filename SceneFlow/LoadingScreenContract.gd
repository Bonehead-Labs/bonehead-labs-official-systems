class_name FlowLoadingScreen
extends CanvasLayer

const FlowAsyncLoader = preload("res://SceneFlow/AsyncSceneLoader.gd")

## Called when FlowManager begins an asynchronous scene load.
func begin_loading(handle: FlowAsyncLoader.LoadHandle) -> void:
    pass

## Called periodically with progress updates (0-1) and contextual metadata.
func update_progress(progress: float, metadata: Dictionary) -> void:
    pass

## Called when loading completes or is cancelled. success indicates whether the target scene loaded.
func finish_loading(success: bool, metadata: Dictionary = {}) -> void:
    pass
