class_name FactionManager
extends Node

## Singleton manager for faction relationships and team-based gameplay.
## Provides APIs for faction compatibility checking and team management.

const EventTopics = preload("res://EventBus/EventTopics.gd")

enum Relationship {
	NEUTRAL,    # No special relationship
	ALLY,       # Allied factions (cannot damage each other)
	ENEMY,      # Enemy factions (can damage each other)
	IGNORE      # Completely ignore each other (no interaction)
}

# Built-in faction constants
const FACTION_NEUTRAL = "neutral"
const FACTION_PLAYER = "player"
const FACTION_ENEMY = "enemy"
const FACTION_ALLY = "ally"
const FACTION_ENVIRONMENT = "environment"

# Faction relationship matrix: faction_a -> faction_b -> relationship
var _relationships: Dictionary = {}
var _registered_factions: Array[String] = []

func _ready() -> void:
	_initialize_default_relationships()

## Initialize default faction relationships
func _initialize_default_relationships() -> void:
	# Register built-in factions
	_register_faction_internal(FACTION_NEUTRAL)
	_register_faction_internal(FACTION_PLAYER)
	_register_faction_internal(FACTION_ENEMY)
	_register_faction_internal(FACTION_ALLY)
	_register_faction_internal(FACTION_ENVIRONMENT)

	# Set up default relationships
	set_relationship(FACTION_PLAYER, FACTION_ENEMY, Relationship.ENEMY)
	set_relationship(FACTION_ENEMY, FACTION_PLAYER, Relationship.ENEMY)
	set_relationship(FACTION_PLAYER, FACTION_ALLY, Relationship.ALLY)
	set_relationship(FACTION_ALLY, FACTION_PLAYER, Relationship.ALLY)
	set_relationship(FACTION_ENEMY, FACTION_ALLY, Relationship.ENEMY)
	set_relationship(FACTION_ALLY, FACTION_ENEMY, Relationship.ENEMY)

	# Environment doesn't attack anyone
	set_relationship(FACTION_ENVIRONMENT, FACTION_NEUTRAL, Relationship.IGNORE)
	set_relationship(FACTION_ENVIRONMENT, FACTION_PLAYER, Relationship.IGNORE)
	set_relationship(FACTION_ENVIRONMENT, FACTION_ENEMY, Relationship.IGNORE)
	set_relationship(FACTION_ENVIRONMENT, FACTION_ALLY, Relationship.IGNORE)

## Register a new faction
func register_faction(faction_name: String) -> bool:
	if _registered_factions.has(faction_name):
		push_warning("FactionManager: Faction '%s' already registered" % faction_name)
		return false

	_register_faction_internal(faction_name)

	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").call("pub", EventTopics.FACTION_REGISTERED, {
			"faction": faction_name,
			"timestamp_ms": Time.get_ticks_msec()
		})

	return true

## Internal faction registration
func _register_faction_internal(faction_name: String) -> void:
	if not _registered_factions.has(faction_name):
		_registered_factions.append(faction_name)
		_relationships[faction_name] = {}

## Unregister a faction
func unregister_faction(faction_name: String) -> bool:
	if not _registered_factions.has(faction_name):
		push_warning("FactionManager: Faction '%s' not registered" % faction_name)
		return false

	# Remove from registered list
	_registered_factions.erase(faction_name)

	# Remove all relationships involving this faction
	_relationships.erase(faction_name)
	for faction in _relationships:
		_relationships[faction].erase(faction_name)

	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").call("pub", EventTopics.FACTION_UNREGISTERED, {
			"faction": faction_name,
			"timestamp_ms": Time.get_ticks_msec()
		})

	return true

## Set relationship between two factions
func set_relationship(faction_a: String, faction_b: String, relationship: Relationship) -> void:
	# Ensure both factions are registered
	if not _registered_factions.has(faction_a):
		_register_faction_internal(faction_a)
	if not _registered_factions.has(faction_b):
		_register_faction_internal(faction_b)

	# Set the relationship
	if not _relationships.has(faction_a):
		_relationships[faction_a] = {}
	_relationships[faction_a][faction_b] = relationship

	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").call("pub", EventTopics.FACTION_RELATIONSHIP_CHANGED, {
			"faction_a": faction_a,
			"faction_b": faction_b,
			"relationship": Relationship.keys()[relationship],
			"timestamp_ms": Time.get_ticks_msec()
		})

## Get relationship between two factions
func get_relationship(faction_a: String, faction_b: String) -> Relationship:
	if faction_a == faction_b:
		return Relationship.ALLY  # Same faction is always allied

	if _relationships.has(faction_a) and _relationships[faction_a].has(faction_b):
		return _relationships[faction_a][faction_b]

	# Default to neutral if no relationship defined
	return Relationship.NEUTRAL

## Check if faction_a can damage faction_b
func can_damage(faction_a: String, faction_b: String) -> bool:
	var relationship = get_relationship(faction_a, faction_b)
	match relationship:
		Relationship.ALLY, Relationship.IGNORE:
			return false
		Relationship.ENEMY, Relationship.NEUTRAL:
			return true
		_:
			return true

## Check if faction_a is allied with faction_b
func is_ally(faction_a: String, faction_b: String) -> bool:
	return get_relationship(faction_a, faction_b) == Relationship.ALLY

## Check if faction_a is enemy of faction_b
func is_enemy(faction_a: String, faction_b: String) -> bool:
	return get_relationship(faction_a, faction_b) == Relationship.ENEMY

## Check if factions ignore each other
func does_ignore(faction_a: String, faction_b: String) -> bool:
	return get_relationship(faction_a, faction_b) == Relationship.IGNORE

## Get all registered factions
func get_registered_factions() -> Array[String]:
	return _registered_factions.duplicate()

## Check if faction is registered
func is_faction_registered(faction_name: String) -> bool:
	return _registered_factions.has(faction_name)

## Get all factions that can damage the given faction
func get_damageable_factions(target_faction: String) -> Array[String]:
	var damageable: Array[String] = []
	for faction in _registered_factions:
		if can_damage(faction, target_faction):
			damageable.append(faction)
	return damageable

## Get all factions allied with the given faction
func get_allied_factions(faction: String) -> Array[String]:
	var allies: Array[String] = []
	for other_faction in _registered_factions:
		if is_ally(faction, other_faction):
			allies.append(other_faction)
	return allies

## Get all factions that are enemies of the given faction
func get_enemy_factions(faction: String) -> Array[String]:
	var enemies: Array[String] = []
	for other_faction in _registered_factions:
		if is_enemy(faction, other_faction):
			enemies.append(other_faction)
	return enemies

## Create a faction group (all factions in group are allied)
func create_faction_group(faction_names: Array[String], group_name: String = "") -> void:
	for i in range(faction_names.size()):
		for j in range(i + 1, faction_names.size()):
			set_relationship(faction_names[i], faction_names[j], Relationship.ALLY)
			set_relationship(faction_names[j], faction_names[i], Relationship.ALLY)

	if group_name != "":
		print("FactionManager: Created faction group '%s' with %d factions" % [group_name, faction_names.size()])

## Make two factions enemies (and their allies)
func declare_war(faction_a: String, faction_b: String) -> void:
	set_relationship(faction_a, faction_b, Relationship.ENEMY)
	set_relationship(faction_b, faction_a, Relationship.ENEMY)

	# Make allies of faction_a enemies of faction_b and vice versa
	var allies_a = get_allied_factions(faction_a)
	var allies_b = get_allied_factions(faction_b)

	for ally_a in allies_a:
		for ally_b in allies_b:
			set_relationship(ally_a, ally_b, Relationship.ENEMY)
			set_relationship(ally_b, ally_a, Relationship.ENEMY)

	print("FactionManager: War declared between '%s' and '%s'" % [faction_a, faction_b])

## Clear all relationships (reset to neutral)
func reset_relationships() -> void:
	_relationships.clear()
	_initialize_default_relationships()

	print("FactionManager: All faction relationships reset")

## Debug: Print current faction relationships
func debug_print_relationships() -> void:
	print("=== FACTION RELATIONSHIPS ===")
	for faction_a in _registered_factions:
		for faction_b in _registered_factions:
			if faction_a != faction_b:
				var relationship = get_relationship(faction_a, faction_b)
				var rel_name = Relationship.keys()[relationship]
				print("%s -> %s: %s" % [faction_a, faction_b, rel_name])
	print("===========================")

## Save faction data
func save_data() -> Dictionary:
	var relationship_data = {}
	for faction_a in _relationships:
		relationship_data[faction_a] = {}
		for faction_b in _relationships[faction_a]:
			relationship_data[faction_a][faction_b] = _relationships[faction_a][faction_b]

	return {
		"registered_factions": _registered_factions.duplicate(),
		"relationships": relationship_data
	}

## Load faction data
func load_data(data: Dictionary) -> bool:
	if data.has("registered_factions"):
		_registered_factions = data["registered_factions"].duplicate()

	if data.has("relationships"):
		_relationships = data["relationships"].duplicate()

	return true
