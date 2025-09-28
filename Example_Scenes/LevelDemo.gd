class_name LevelDemo
extends Node2D

## Main demo script that integrates AudioService and UI systems.
## This script coordinates all the demo components in the sample level.

@onready var _pause_menu: Control = $PauseMenuDemo

var _audio_demo: Node

func _ready() -> void:
	print("LevelDemo: Initializing demo...")
	
	# Create and setup audio demo
	_setup_audio_demo()
	
	
	# Start background music
	_start_background_music()
	
	print("LevelDemo: Demo initialization complete!")

## Setup the audio demo system
func _setup_audio_demo() -> void:
	_audio_demo = AudioDemo.new()
	_audio_demo.name = "AudioDemo"
	add_child(_audio_demo)
	
	# Add to group for easy finding
	_audio_demo.add_to_group("audio_demo")
	
	print("LevelDemo: Audio demo setup complete")


## Start the background music
func _start_background_music() -> void:
	if _audio_demo == null:
		push_error("LevelDemo: Audio demo not available!")
		return
	
	# Wait a frame for audio to initialize
	await get_tree().process_frame
	_audio_demo.start_music()
	
	print("LevelDemo: Background music started")

## Get the audio demo instance
func get_audio_demo() -> Node:
	return _audio_demo


## Check if the demo is paused
func is_paused() -> bool:
	if _pause_menu != null:
		return _pause_menu.is_paused()
	return false
