extends Control

var received_contexts: Array[Dictionary[StringName, Variant]] = []
var entered_count: int = 0
var exited_count: int = 0

func receive_context(context: Dictionary[StringName, Variant]) -> void:
    received_contexts.append(context.duplicate(true))

func on_screen_entered(context: Dictionary[StringName, Variant]) -> void:
    entered_count += 1

func on_screen_exited(context: Dictionary[StringName, Variant]) -> void:
    exited_count += 1
