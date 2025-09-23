class_name WaveManager
extends Resource

@export var waves: Array = []  # Array of Dictionaries: {scene: PackedScene, count: int, interval: float}

func get_wave(index: int) -> Dictionary:
    if index < 0 or index >= waves.size():
        return {}
    return waves[index]

func size() -> int:
    return waves.size()

