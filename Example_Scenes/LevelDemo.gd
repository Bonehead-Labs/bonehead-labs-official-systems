class_name LevelDemo
extends Node2D

## Main demo script that integrates AudioService and UI systems.
## This script coordinates all the demo components in the sample level.

@onready var _pause_menu: Control = $PauseMenuDemo

# Audio configuration
const SAMPLE_AUDIO_PATH = "res://AudioService/sample-audio/"
const MUSIC_TRACK = "sample-track.mp3"
const HIT_SOUNDS = ["Hit_1.wav", "Hit_2.wav", "Hit_3.wav"]

var _hit_sound_group: Array[StringName] = []

func _ready() -> void:
	print("LevelDemo: Initializing demo...")
	
	# Initialize audio directly with AudioService
	_initialize_audio()
	
	# Start background music
	_start_background_music()
	
	print("LevelDemo: Demo initialization complete!")

## Initialize audio using AudioService bulk loading functionality
func _initialize_audio() -> void:
	if AudioService.is_initialized():
		return
		
	print("LevelDemo: Initializing audio using AudioService bulk loading...")
	
	# Use the bulk loading functionality
	var results := AudioService.load_sounds_from_directory(
		SAMPLE_AUDIO_PATH,
		["mp3", "wav"],  # Only load mp3 and wav files
		"demo_",         # Prefix for sound IDs
		AudioService.BUS_SFX,  # Default bus
		"SFX",           # Default kind
		false            # Not recursive
	)
	
	# Log loading results
	var success_count := 0
	for path in results.keys():
		if results[path]:
			success_count += 1
	print("LevelDemo: Loaded %d/%d audio files successfully" % [success_count, results.size()])
	
	# Register music track separately with proper bus and kind
	var music_path = SAMPLE_AUDIO_PATH + MUSIC_TRACK
	var music_stream = load(music_path)
	if music_stream != null:
		AudioService.register_sound("demo_music", music_stream, AudioService.BUS_MUSIC, "MUSIC")
		print("LevelDemo: Registered music track: ", music_path)
	else:
		push_error("LevelDemo: Failed to load music track: " + music_path)
	
	# Build hit sound group for random selection
	for i in range(HIT_SOUNDS.size()):
		var sound_id = "demo_" + HIT_SOUNDS[i].get_basename()
		_hit_sound_group.append(sound_id)
	
	# Mark AudioService as initialized
	AudioService.mark_initialized()
	print("LevelDemo: Audio initialization complete!")

## Start the background music
func _start_background_music() -> void:
	if not AudioService.is_initialized():
		_initialize_audio()
		await get_tree().process_frame
	
	print("LevelDemo: Starting background music...")
	AudioService.play_music_by_id("demo_music", 1.0, true)  # 1 second fade, looped
	print("LevelDemo: Background music started")

## Play a random hit sound effect (for use by other systems)
func play_random_hit() -> void:
	if not AudioService.is_initialized():
		_initialize_audio()
		await get_tree().process_frame
	
	if _hit_sound_group.is_empty():
		push_warning("LevelDemo: No hit sounds available")
		return
	
	print("LevelDemo: Playing random hit sound...")
	AudioService.play_random_sound(_hit_sound_group, {"vol_db": -5.0}, "sfx")

## Check if the demo is paused
func is_paused() -> bool:
	if _pause_menu != null:
		return _pause_menu.is_paused()
	return false
