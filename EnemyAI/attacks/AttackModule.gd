class_name AttackModule
extends RefCounted

## Strategy interface for enemy attacks

func begin(_owner: Node, _target: Node2D) -> void:
    pass

func update(_owner: Node, _delta: float) -> bool:
    # Return true when attack finished
    return true

func cancel(_owner: Node) -> void:
    pass

