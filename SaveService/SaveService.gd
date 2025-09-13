class_name _SaveService extends Node

## SaveService (Godot 4)
## A robust, profile-based save system with JSON serialization,
## validation, auto-save, checkpoints, and helpful signals.
##
## Usage
## - Add this script as an autoload singleton named `SaveService`.
## - Implement the save protocol in your game objects:
##   - `save_data() -> Dictionary`
##   - `load_data(data: Dictionary) -> bool`
##   - `get_save_id() -> String`
##   - `get_save_priority() -> int` (lower saves/loads first)
## - Optionally, extend the helper interface class `_ISaveable` in
##   `SaveService/ISaveable.gd` for clearer intent.
##
## Notes
## - This script's class name is `_SaveService` to avoid conflicts in the
##   editor. Access it via the autoload name `SaveService`.
## - Save data is stored under `user://saves/<profile>/*.json`.

# ---- signals ----
## Emitted when the active profile changes.
## id: The new active profile identifier.
signal profile_changed(id: String)

## Emitted immediately before a save operation begins.
## save_id: The save slot/key to write.
signal before_save(save_id: String)

## Emitted after a save operation completes.
## save_id: The save slot/key. success: True if save succeeded.
signal after_save(save_id: String, success: bool)

## Emitted immediately before a load operation begins.
## save_id: The save slot/key to read.
signal before_load(save_id: String)

## Emitted after a load operation completes.
## save_id: The save slot/key. success: True if load succeeded.
signal after_load(save_id: String, success: bool)

## Emitted when a recoverable error occurs inside the service.
## code: Short error key. message: Human-readable explanation.
signal error(code: String, message: String)

## Emitted when a checkpoint is created for the current profile.
## save_id: The checkpoint name.
signal checkpoint_created(save_id: String)

## Emitted when the auto-save timer triggers a save attempt.
signal autosave_triggered()

# ---- constants / config ----
## Root directory for all profiles and save files.
const SAVE_ROOT         := "user://saves"

## Reserved filename for storing profile metadata (last save, etc.).
const PROFILE_FILE      := "profile.json"

## Metadata file tracking last save info per profile.
const META_FILE         := "meta.json"

## Directory (under a profile) where checkpoints are stored.
const CHECKPOINT_DIR    := "checkpoints"

## Default filename used by auto-save (stored in the profile root).
const AUTOSAVE_FILE     := "autosave.json"

## Increment when the save data structure changes to prevent mismatches.
const SCHEMA_VERSION    := 1

## Optional application version string recorded in save metadata.
const APP_VERSION       := "0.1.0"

# ---- configuration ----
## When true, validation is strict and operations may fail fast on issues.
var strict_mode: bool = true

## When true, the service runs an internal timer to auto-save periodically.
var auto_save_enabled: bool = true

## Number of seconds between auto-save attempts (when enabled).
var auto_save_interval: float = 300.0  # 5 minutes

## Maximum number of checkpoints to retain per profile (oldest removed first).
var max_checkpoints: int = 10

# ---- internal state ----
## Currently active profile id. Must be set before saving/loading.
var current_profile_id: String = ""

## Registered objects that participate in save/load.
## Each object should implement the save protocol methods listed above.
var _registered_saveables: Array = []

var _auto_save_timer: Timer
var _id_regex: RegEx
# var _save_queue: Array[Dictionary] = []  # Reserved for potential async pipeline
var _is_saving: bool = false
var _is_loading: bool = false

# ---- lifecycle / setup ----
## Initializes internal resources (regex, directories, auto-save timer).
func _ready() -> void:
	_setup_regex()
	_setup_directories()
	_setup_auto_save()

func _setup_regex() -> void:
	_id_regex = RegEx.new()
	_id_regex.compile("^[A-Za-z0-9_\\-]{1,24}$")

func _setup_directories() -> void:
	var err = DirAccess.make_dir_recursive_absolute(SAVE_ROOT)
	if err != OK and err != ERR_ALREADY_EXISTS:
		emit_signal("error", "SETUP_FAILED", "Could not create save directory: %s" % str(err))

func _setup_auto_save() -> void:
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = auto_save_interval
	_auto_save_timer.timeout.connect(_on_auto_save_timeout)
	add_child(_auto_save_timer)
	
	if auto_save_enabled:
		_auto_save_timer.start()


func _profile_dir(id: String) -> String:
	return "%s/%s" % [SAVE_ROOT, id]

func _is_valid_profile_id(id: String) -> bool:
	return _id_regex.search(id) != null

## Lists existing profile directory names under `SAVE_ROOT`.
## Returns an empty array if the directory is not accessible.
func list_profiles() -> PackedStringArray:
	var profiles := PackedStringArray()
	var dir := DirAccess.open(SAVE_ROOT)
	if dir == null: 
		emit_signal("error", "DIR_ACCESS_FAILED", "Could not access save directory")
		return profiles
	
	dir.list_dir_begin()
	while true:
		var dir_name := dir.get_next()
		if dir_name == "": break
		if dir.current_is_dir() and not dir_name.begins_with("."):
			profiles.append(dir_name)
	dir.list_dir_end()
	return profiles

## Creates (if needed) and switches to a profile.
## Returns true when the profile is ready and active.
## In strict mode, profile ids must match: ^[A-Za-z0-9_\-]{1,24}$
func set_current_profile(id: String) -> bool:
	if strict_mode and not _is_valid_profile_id(id):
		emit_signal("error", "INVALID_PROFILE_ID", "Profile ID must be 1-24 chars: A-Z, a-z, 0-9, _, -")
		return false

	var profile_path := _profile_dir(id)
	if not DirAccess.dir_exists_absolute(profile_path):
		var err := DirAccess.make_dir_recursive_absolute(profile_path)
		if err != OK:
			emit_signal("error", "PROFILE_CREATE_FAILED", "Could not create profile directory: %s" % str(err))
			return false
		
		# Create checkpoint directory
		var checkpoint_path := "%s/%s" % [profile_path, CHECKPOINT_DIR]
		DirAccess.make_dir_recursive_absolute(checkpoint_path)

	current_profile_id = id
	emit_signal("profile_changed", id)
	return true

## Returns the active profile id, or empty string if none.
func get_current_profile() -> String:
	return current_profile_id

## Permanently deletes a profile directory and all contained saves.
## Returns false if attempting to delete the active profile.
func delete_profile(id: String) -> bool:
	if id == current_profile_id:
		emit_signal("error", "CANNOT_DELETE_ACTIVE", "Cannot delete currently active profile")
		return false
	
	var profile_path := _profile_dir(id)
	if not DirAccess.dir_exists_absolute(profile_path):
		return true  # Already doesn't exist
	
	var dir := DirAccess.open(profile_path)
	if dir == null:
		emit_signal("error", "DELETE_FAILED", "Could not access profile directory")
		return false
	
	# Recursively delete directory contents
	_delete_directory_recursive(dir)
	var err := DirAccess.remove_absolute(profile_path)
	return err == OK

func _delete_directory_recursive(dir: DirAccess) -> void:
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "": break
		if file_name.begins_with("."): continue
		
		if dir.current_is_dir():
			var sub_dir := DirAccess.open(dir.get_current_dir() + "/" + file_name)
			if sub_dir:
				_delete_directory_recursive(sub_dir)
				DirAccess.remove_absolute(dir.get_current_dir() + "/" + file_name)
		else:
			dir.remove(file_name)
	dir.list_dir_end()

# ---- Saveable Registration ----
## Registers an object to participate in save/load.
## The object must implement: save_data, load_data, get_save_id, get_save_priority.
func register_saveable(saveable) -> void:
	if saveable in _registered_saveables:
		return
	
	if strict_mode:
		var save_id: String = saveable.get_save_id()
		if save_id.is_empty():
			emit_signal("error", "INVALID_SAVE_ID", "Saveable must have a non-empty save ID")
			return
		
		# Check for duplicate IDs
		for existing in _registered_saveables:
			if existing.get_save_id() == save_id:
				emit_signal("error", "DUPLICATE_SAVE_ID", "Save ID '%s' already registered" % save_id)
				return
	
	_registered_saveables.append(saveable)

## Unregisters a previously registered saveable object.
func unregister_saveable(saveable) -> void:
	_registered_saveables.erase(saveable)

## Returns a shallow copy of the registered saveables list.
func get_registered_saveables() -> Array:
	return _registered_saveables.duplicate()

# ---- Serialization System ----
## Internal: Collects and serializes registered saveables into a Dictionary.
func _serialize_saveables() -> Dictionary:
	var data := {
		"meta": {
			"schema_version": SCHEMA_VERSION,
			"app_version": APP_VERSION,
			"profile_id": current_profile_id,
			"timestamp": Time.get_unix_time_from_system(),
			"save_count": _registered_saveables.size()
		},
		"saveables": {}
	}
	
	# Sort by priority (lower numbers first)
	var sorted_saveables := _registered_saveables.duplicate()
	sorted_saveables.sort_custom(func(a, b): return a.get_save_priority() < b.get_save_priority())
	
	for saveable in sorted_saveables:
		var save_id: String = saveable.get_save_id()
		if save_id.is_empty():
			if strict_mode:
				emit_signal("error", "EMPTY_SAVE_ID", "Saveable has empty save ID")
				continue
			else:
				save_id = "unnamed_%d" % saveable.get_instance_id()
		
		var saveable_data: Dictionary = saveable.save_data()
		if saveable_data.is_empty() and strict_mode:
			emit_signal("error", "EMPTY_SAVE_DATA", "Saveable '%s' returned empty data" % save_id)
			continue
		
		data.saveables[save_id] = {
			"priority": saveable.get_save_priority(),
			"data": saveable_data
		}
	
	return data

## Internal: Applies serialized data to registered saveables.
## Returns true if all saveables loaded or strict mode is disabled.
func _deserialize_to_saveables(data: Dictionary) -> bool:
	if not data.has("saveables"):
		emit_signal("error", "INVALID_SAVE_FORMAT", "Save data missing 'saveables' section")
		return false
	
	var saveables_data: Dictionary = data.saveables
	var success_count := 0
	var total_count := _registered_saveables.size()
	
	# Sort by priority for loading
	var sorted_saveables := _registered_saveables.duplicate()
	sorted_saveables.sort_custom(func(a, b): return a.get_save_priority() < b.get_save_priority())
	
	for saveable in sorted_saveables:
		var save_id: String = saveable.get_save_id()
		if not saveables_data.has(save_id):
			if strict_mode:
				emit_signal("error", "MISSING_SAVE_DATA", "No save data found for '%s'" % save_id)
				continue
			else:
				continue  # Skip missing data in non-strict mode
		
		var saveable_entry: Dictionary = saveables_data[save_id]
		if not saveable_entry.has("data"):
			emit_signal("error", "MALFORMED_SAVE_DATA", "Malformed save data for '%s'" % save_id)
			continue
		
		if saveable.load_data(saveable_entry.data):
			success_count += 1
		else:
			emit_signal("error", "LOAD_FAILED", "Failed to load data for '%s'" % save_id)
	
	return success_count == total_count or not strict_mode

# ---- Save Pipeline ----
## Saves all registered saveables into `<profile>/<save_id>.json`.
## Emits `before_save` and `after_save`. Returns true on success.
func save_game(save_id: String = "main") -> bool:
	if current_profile_id.is_empty():
		emit_signal("error", "NO_PROFILE", "No profile selected")
		return false
	
	if _is_saving:
		emit_signal("error", "SAVE_IN_PROGRESS", "Save operation already in progress")
		return false
	
	_is_saving = true
	emit_signal("before_save", save_id)
	
	var success := _perform_save(save_id)
	
	_is_saving = false
	emit_signal("after_save", save_id, success)
	return success

## Internal: Performs the actual file write and metadata update.
func _perform_save(save_id: String) -> bool:
	var save_data := _serialize_saveables()
	var save_path := "%s/%s.json" % [_profile_dir(current_profile_id), save_id]
	
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		emit_signal("error", "FILE_WRITE_FAILED", "Could not open save file: %s" % save_path)
		return false
	
	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	# Also save metadata
	_save_metadata(save_id, save_data.meta)
	
	return true

## Internal: Updates the profile's `meta.json` with last save info.
func _save_metadata(save_id: String, meta_data: Dictionary) -> void:
	var meta_path := "%s/%s" % [_profile_dir(current_profile_id), META_FILE]
	var existing_meta := {}
	
	# Load existing metadata
	if FileAccess.file_exists(meta_path):
		var read_file := FileAccess.open(meta_path, FileAccess.READ)
		if read_file:
			var json := JSON.new()
			var parse_result := json.parse(read_file.get_as_text())
			if parse_result == OK:
				existing_meta = json.data
			read_file.close()
	
	# Update with new save info
	if not existing_meta.has("saves"):
		existing_meta.saves = {}
	
	existing_meta.saves[save_id] = meta_data
	existing_meta.last_save = save_id
	existing_meta.last_updated = Time.get_unix_time_from_system()
	
	# Write updated metadata
	var write_file := FileAccess.open(meta_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(JSON.stringify(existing_meta, "\t"))
		write_file.close()

# ---- Load Pipeline ----
## Loads and applies data from `<profile>/<save_id>.json`.
## Emits `before_load` and `after_load`. Returns true on success.
func load_game(save_id: String = "main") -> bool:
	if current_profile_id.is_empty():
		emit_signal("error", "NO_PROFILE", "No profile selected")
		return false
	
	if _is_loading:
		emit_signal("error", "LOAD_IN_PROGRESS", "Load operation already in progress")
		return false
	
	_is_loading = true
	emit_signal("before_load", save_id)
	
	var success := _perform_load(save_id)
	
	_is_loading = false
	emit_signal("after_load", save_id, success)
	return success

## Internal: Reads, parses, validates, and dispatches save data by id.
func _perform_load(save_id: String) -> bool:
	var save_path := "%s/%s.json" % [_profile_dir(current_profile_id), save_id]
	
	if not FileAccess.file_exists(save_path):
		emit_signal("error", "SAVE_NOT_FOUND", "Save file not found: %s" % save_path)
		return false
	
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		emit_signal("error", "FILE_READ_FAILED", "Could not open save file: %s" % save_path)
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		emit_signal("error", "JSON_PARSE_FAILED", "Invalid JSON in save file")
		return false
	
	var save_data: Dictionary = json.data
	
	# Validate save data
	if not _validate_save_data(save_data):
		return false
	
	return _deserialize_to_saveables(save_data)

## Internal: Performs minimal validation against expected schema.
func _validate_save_data(data: Dictionary) -> bool:
	if not data.has("meta"):
		emit_signal("error", "INVALID_SAVE_FORMAT", "Save data missing metadata")
		return false
	
	var meta: Dictionary = data.meta
	
	if strict_mode:
		if not meta.has("schema_version"):
			emit_signal("error", "MISSING_SCHEMA_VERSION", "Save data missing schema version")
			return false
		
		var save_schema: int = meta.get("schema_version", 0)
		if save_schema != SCHEMA_VERSION:
			emit_signal("error", "SCHEMA_MISMATCH", "Save schema version %d, expected %d" % [save_schema, SCHEMA_VERSION])
			return false
	
	return true

# ---- Auto-Save & Checkpoints ----
## Enables or disables the auto-save timer.
func enable_auto_save(enabled: bool) -> void:
	auto_save_enabled = enabled
	if enabled and _auto_save_timer:
		_auto_save_timer.start()
	elif _auto_save_timer:
		_auto_save_timer.stop()

## Sets the auto-save interval in seconds.
func set_auto_save_interval(seconds: float) -> void:
	auto_save_interval = seconds
	if _auto_save_timer:
		_auto_save_timer.wait_time = seconds

## Internal: Timer callback that triggers an auto-save when possible.
func _on_auto_save_timeout() -> void:
	if current_profile_id.is_empty() or _registered_saveables.is_empty():
		return
	
	emit_signal("autosave_triggered")
	save_game(AUTOSAVE_FILE.get_basename())  # Save as "autosave"

## Saves a checkpoint under `<profile>/checkpoints/<name>.json`.
## Generates a timestamp name when none is provided.
func create_checkpoint(checkpoint_name: String = "") -> bool:
	if current_profile_id.is_empty():
		emit_signal("error", "NO_PROFILE", "No profile selected")
		return false
	
	if checkpoint_name.is_empty():
		checkpoint_name = "checkpoint_%d" % Time.get_unix_time_from_system()
	
	var checkpoint_dir := "%s/%s" % [_profile_dir(current_profile_id), CHECKPOINT_DIR]
	var checkpoint_path := "%s/%s.json" % [checkpoint_dir, checkpoint_name]
	
	# Ensure checkpoint directory exists
	DirAccess.make_dir_recursive_absolute(checkpoint_dir)
	
	# Save checkpoint
	var save_data := _serialize_saveables()
	var file := FileAccess.open(checkpoint_path, FileAccess.WRITE)
	if file == null:
		emit_signal("error", "CHECKPOINT_FAILED", "Could not create checkpoint file")
		return false
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	
	# Clean up old checkpoints
	_cleanup_old_checkpoints()
	
	emit_signal("checkpoint_created", checkpoint_name)
	return true

## Lists checkpoint names (without `.json`) for the active profile.
func list_checkpoints() -> PackedStringArray:
	var checkpoints := PackedStringArray()
	if current_profile_id.is_empty():
		return checkpoints
	
	var checkpoint_dir := "%s/%s" % [_profile_dir(current_profile_id), CHECKPOINT_DIR]
	var dir := DirAccess.open(checkpoint_dir)
	if dir == null:
		return checkpoints
	
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "": break
		if file_name.ends_with(".json"):
			checkpoints.append(file_name.get_basename())
	dir.list_dir_end()
	
	return checkpoints

## Loads a checkpoint by name for the active profile.
func load_checkpoint(checkpoint_name: String) -> bool:
	if current_profile_id.is_empty():
		emit_signal("error", "NO_PROFILE", "No profile selected")
		return false
	
	var checkpoint_path := "%s/%s/%s.json" % [_profile_dir(current_profile_id), CHECKPOINT_DIR, checkpoint_name]
	
	if not FileAccess.file_exists(checkpoint_path):
		emit_signal("error", "CHECKPOINT_NOT_FOUND", "Checkpoint not found: %s" % checkpoint_name)
		return false
	
	return _perform_load_from_path(checkpoint_path)

## Internal: Loads data from an explicit file path (used by checkpoints).
func _perform_load_from_path(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		emit_signal("error", "FILE_READ_FAILED", "Could not open file: %s" % file_path)
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		emit_signal("error", "JSON_PARSE_FAILED", "Invalid JSON in file")
		return false
	
	var save_data: Dictionary = json.data
	if not _validate_save_data(save_data):
		return false
	
	return _deserialize_to_saveables(save_data)

## Internal: Ensures the number of checkpoint files does not exceed the limit.
func _cleanup_old_checkpoints() -> void:
	var checkpoint_dir := "%s/%s" % [_profile_dir(current_profile_id), CHECKPOINT_DIR]
	var dir := DirAccess.open(checkpoint_dir)
	if dir == null:
		return
	
	var checkpoint_files: Array[String] = []
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "": break
		if file_name.ends_with(".json"):
			checkpoint_files.append(file_name)
	dir.list_dir_end()
	
	if checkpoint_files.size() <= max_checkpoints:
		return
	
	# Sort by modification time (oldest first)
	checkpoint_files.sort_custom(func(a, b):
		var time_a := FileAccess.get_modified_time("%s/%s" % [checkpoint_dir, a])
		var time_b := FileAccess.get_modified_time("%s/%s" % [checkpoint_dir, b])
		return time_a < time_b
	)
	
	# Remove oldest files
	var files_to_remove := checkpoint_files.size() - max_checkpoints
	for i in range(files_to_remove):
		dir.remove(checkpoint_files[i])

# ---- Utility Functions ----
## Returns true if `<profile>/<save_id>.json` exists for the active profile.
func has_save(save_id: String) -> bool:
	if current_profile_id.is_empty():
		return false
	var save_path := "%s/%s.json" % [_profile_dir(current_profile_id), save_id]
	return FileAccess.file_exists(save_path)

## Deletes `<profile>/<save_id>.json` if it exists. Returns true on success.
func delete_save(save_id: String) -> bool:
	if current_profile_id.is_empty():
		emit_signal("error", "NO_PROFILE", "No profile selected")
		return false
	
	var save_path := "%s/%s.json" % [_profile_dir(current_profile_id), save_id]
	if not FileAccess.file_exists(save_path):
		return true  # Already doesn't exist
	
	var dir := DirAccess.open(_profile_dir(current_profile_id))
	if dir == null:
		return false
	
	return dir.remove("%s.json" % save_id) == OK

## Lists save names (without `.json`) for the active profile.
func list_saves() -> PackedStringArray:
	var saves := PackedStringArray()
	if current_profile_id.is_empty():
		return saves
	
	var profile_path := _profile_dir(current_profile_id)
	var dir := DirAccess.open(profile_path)
	if dir == null:
		return saves
	
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "": break
		if file_name.ends_with(".json") and not file_name.begins_with("."):
			saves.append(file_name.get_basename())
	dir.list_dir_end()
	
	return saves

# ---- Configuration ----
## Enables or disables strict validation behavior.
func set_strict_mode(enabled: bool) -> void:
	strict_mode = enabled

## Sets the maximum number of retained checkpoints (minimum 1).
func set_max_checkpoints(count: int) -> void:
	max_checkpoints = max(1, count)

## Returns a snapshot of internal configuration and state for diagnostics.
func get_save_statistics() -> Dictionary:
	return {
		"current_profile": current_profile_id,
		"registered_saveables": _registered_saveables.size(),
		"auto_save_enabled": auto_save_enabled,
		"auto_save_interval": auto_save_interval,
		"strict_mode": strict_mode,
		"max_checkpoints": max_checkpoints,
		"is_saving": _is_saving,
		"is_loading": _is_loading
	}

