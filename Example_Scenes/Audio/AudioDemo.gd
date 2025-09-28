class_name AudioDemo
extends Node

# AudioService is an autoload singleton

## AudioService demo showcasing music and sound effects integration.
## This demo registers sample audio files and provides methods to play them.

const SAMPLE_AUDIO_PATH = "res://AudioService/sample-audio/"

# Sample audio files
const MUSIC_TRACK = "sample-track.mp3"
const HIT_SOUNDS = ["Hit_1.wav", "Hit_2.wav", "Hit_3.wav"]

var _is_initialized: bool = false

func _ready() -> void:
	# Wait for AudioService to be ready
	await get_tree().process_frame
	_initialize_audio()

## Initialize audio by registering all sample sounds with AudioService
func _initialize_audio() -> void:
	if _is_initialized:
		return
		
	print("AudioDemo: Initializing audio...")
	
	# Register music track
	var music_path = SAMPLE_AUDIO_PATH + MUSIC_TRACK
	var music_stream = load(music_path)
	if music_stream != null:
		AudioService.register_sound("demo_music", music_stream, AudioService.BUS_MUSIC, "MUSIC")
		print("AudioDemo: Registered music track: ", music_path)
	else:
		push_error("AudioDemo: Failed to load music track: " + music_path)
	
	# Register hit sound effects
	for i in range(HIT_SOUNDS.size()):
		var hit_sound = HIT_SOUNDS[i]
		var hit_path = SAMPLE_AUDIO_PATH + hit_sound
		var hit_stream = load(hit_path)
		if hit_stream != null:
			var sound_id = "demo_hit_%d" % (i + 1)
			AudioService.register_sound(sound_id, hit_stream, AudioService.BUS_SFX, "SFX")
			print("AudioDemo: Registered hit sound: ", sound_id, " -> ", hit_path)
		else:
			push_error("AudioDemo: Failed to load hit sound: " + hit_path)
	
	_is_initialized = true
	print("AudioDemo: Audio initialization complete!")

## Start playing the background music
func start_music() -> void:
	if not _is_initialized:
		_initialize_audio()
		await get_tree().process_frame
	
	print("AudioDemo: Starting background music...")
	AudioService.play_music_by_id("demo_music", 1.0, true)  # 1 second fade, looped

## Stop the background music
func stop_music() -> void:
	print("AudioDemo: Stopping background music...")
	AudioService.stop_music(1.0)  # 1 second fade out

## Play a random hit sound effect
func play_random_hit() -> void:
	if not _is_initialized:
		_initialize_audio()
		await get_tree().process_frame
	
	var random_index = randi() % HIT_SOUNDS.size()
	var sound_id = "demo_hit_%d" % (random_index + 1)
	
	print("AudioDemo: Playing random hit sound: ", sound_id)
	AudioService.play_sfx(sound_id, {"vol_db": -5.0})  # Slightly quieter

## Play a specific hit sound by index (0-2)
func play_hit_sound(index: int) -> void:
	if not _is_initialized:
		_initialize_audio()
		await get_tree().process_frame
	
	if index < 0 or index >= HIT_SOUNDS.size():
		push_warning("AudioDemo: Invalid hit sound index: " + str(index))
		return
	
	var sound_id = "demo_hit_%d" % (index + 1)
	print("AudioDemo: Playing hit sound: ", sound_id)
	AudioService.play_sfx(sound_id, {"vol_db": -5.0})

## Get current music volume
func get_music_volume() -> float:
	return AudioService.get_bus_volume_db(AudioService.BUS_MUSIC)

## Set music volume
func set_music_volume(volume_db: float) -> void:
	AudioService.set_bus_volume_db(AudioService.BUS_MUSIC, volume_db)
	print("AudioDemo: Music volume set to: ", volume_db, " dB")

## Get master volume
func get_master_volume() -> float:
	return AudioService.get_bus_volume_db(AudioService.BUS_MASTER)

## Set master volume
func set_master_volume(volume_db: float) -> void:
	AudioService.set_bus_volume_db(AudioService.BUS_MASTER, volume_db)
	print("AudioDemo: Master volume set to: ", volume_db, " dB")

## Check if audio is initialized
func is_initialized() -> bool:
	return _is_initialized
