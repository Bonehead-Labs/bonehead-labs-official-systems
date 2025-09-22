class_name FlowLoadingScreen
extends CanvasLayer

const AsyncSceneLoaderScript = preload("res://SceneFlow/AsyncSceneLoader.gd")

## Called when FlowManager begins an asynchronous scene load.
func begin_loading(_handle: AsyncSceneLoaderScript.LoadHandle) -> void:
    pass

## Called periodically with progress updates (0-1) and contextual metadata.
func update_progress(_progress: float, _metadata: Dictionary) -> void:
    pass

## Called when loading completes or is cancelled. success indicates whether the target scene loaded.
func finish_loading(_success: bool, _metadata: Dictionary = {}) -> void:
    pass
