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
## 
## Adds a new faction to the system. Factions must be registered
## before setting relationships or checking compatibility.
## 
## [b]faction_name:[/b] Unique name for the faction
## 
## [b]Returns:[/b] true if registration succeeded, false if already exists
## 
## [b]Usage:[/b]
## [codeblock]
## # Register custom factions
## FactionManager.register_faction("undead")
## FactionManager.register_faction("mercenary")
## 
## # Set up relationships
## FactionManager.set_relationship("undead", "player", FactionManager.Relationship.ENEMY)
## [/codeblock]
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
## 
## Removes a faction from the system and all its relationships.
## 
## [b]faction_name:[/b] Name of the faction to remove
## 
## [b]Returns:[/b] true if unregistration succeeded, false if not found
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove a faction
## FactionManager.unregister_faction("temporary_faction")
## 
## # Check if removal succeeded
## if FactionManager.unregister_faction("old_faction"):
##     print("Faction removed successfully")
## [/codeblock]
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
## 
## Defines how two factions interact with each other.
## 
## [b]faction_a:[/b] First faction
## [b]faction_b:[/b] Second faction
## [b]relationship:[/b] Relationship type (ALLY, ENEMY, NEUTRAL, IGNORE)
## 
## [b]Usage:[/b]
## [codeblock]
## # Make factions enemies
## FactionManager.set_relationship("player", "enemy", FactionManager.Relationship.ENEMY)
## 
## # Make factions allies
## FactionManager.set_relationship("player", "ally", FactionManager.Relationship.ALLY)
## 
## # Make factions ignore each other
## FactionManager.set_relationship("environment", "player", FactionManager.Relationship.IGNORE)
## [/codeblock]
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
## 
## Returns the current relationship between two factions.
## 
## [b]faction_a:[/b] First faction
## [b]faction_b:[/b] Second faction
## 
## [b]Returns:[/b] Relationship type between the factions
## 
## [b]Usage:[/b]
## [codeblock]
## var relationship = FactionManager.get_relationship("player", "enemy")
## if relationship == FactionManager.Relationship.ENEMY:
##     print("Player and enemy are enemies")
## [/codeblock]
func get_relationship(faction_a: String, faction_b: String) -> Relationship:
	if faction_a == faction_b:
		return Relationship.ALLY  # Same faction is always allied

	if _relationships.has(faction_a) and _relationships[faction_a].has(faction_b):
		return _relationships[faction_a][faction_b]

	# Default to neutral if no relationship defined
	return Relationship.NEUTRAL

## Check if one faction can damage another
## 
## Determines if faction_a can deal damage to faction_b based on their relationship.
## 
## [b]faction_a:[/b] Attacking faction
## [b]faction_b:[/b] Target faction
## 
## [b]Returns:[/b] true if damage is allowed, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Check if player can damage enemy
## if FactionManager.can_damage("player", "enemy"):
##     # Deal damage
##     enemy.take_damage(damage_info)
## 
## # Check if ally can damage player (should be false)
## if not FactionManager.can_damage("ally", "player"):
##     print("Allies cannot damage each other")
## [/codeblock]
func can_damage(faction_a: String, faction_b: String) -> bool:
	var relationship: Relationship = get_relationship(faction_a, faction_b)
	match relationship:
		Relationship.ALLY, Relationship.IGNORE:
			return false
		Relationship.ENEMY, Relationship.NEUTRAL:
			return true
		_:
			return true

## Check if two factions are allies
## 
## [b]faction_a:[/b] First faction
## [b]faction_b:[/b] Second faction
## 
## [b]Returns:[/b] true if factions are allied, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if FactionManager.is_ally("player", "ally"):
##     print("Player and ally are allies")
##     # Maybe show ally indicator
## [/codeblock]
func is_ally(faction_a: String, faction_b: String) -> bool:
	return get_relationship(faction_a, faction_b) == Relationship.ALLY

## Check if two factions are enemies
## 
## [b]faction_a:[/b] First faction
## [b]faction_b:[/b] Second faction
## 
## [b]Returns:[/b] true if factions are enemies, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if FactionManager.is_enemy("player", "enemy"):
##     print("Player and enemy are enemies")
##     # Maybe show enemy indicator
## [/codeblock]
func is_enemy(faction_a: String, faction_b: String) -> bool:
	return get_relationship(faction_a, faction_b) == Relationship.ENEMY

## Check if two factions ignore each other
## 
## [b]faction_a:[/b] First faction
## [b]faction_b:[/b] Second faction
## 
## [b]Returns:[/b] true if factions ignore each other, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if FactionManager.does_ignore("environment", "player"):
##     print("Environment and player ignore each other")
##     # No interaction possible
## [/codeblock]
func does_ignore(faction_a: String, faction_b: String) -> bool:
	return get_relationship(faction_a, faction_b) == Relationship.IGNORE

## Get all registered factions
## 
## [b]Returns:[/b] Array of all registered faction names
## 
## [b]Usage:[/b]
## [codeblock]
## var factions = FactionManager.get_registered_factions()
## for faction in factions:
##     print("Registered faction: ", faction)
## [/codeblock]
func get_registered_factions() -> Array[String]:
	return _registered_factions.duplicate()

## Check if a faction is registered
## 
## [b]faction_name:[/b] Name of the faction to check
## 
## [b]Returns:[/b] true if faction is registered, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if FactionManager.is_faction_registered("player"):
##     print("Player faction is registered")
## [/codeblock]
func is_faction_registered(faction_name: String) -> bool:
	return _registered_factions.has(faction_name)

## Get all factions that can damage the target faction
## 
## [b]target_faction:[/b] Faction to check against
## 
## [b]Returns:[/b] Array of faction names that can damage the target
## 
## [b]Usage:[/b]
## [codeblock]
## var threats = FactionManager.get_damageable_factions("player")
## print("Factions that can damage player: ", threats)
## 
## # Check if any enemies can damage player
## if threats.size() > 0:
##     print("Player is under threat!")
## [/codeblock]
func get_damageable_factions(target_faction: String) -> Array[String]:
	var damageable: Array[String] = []
	for faction in _registered_factions:
		if can_damage(faction, target_faction):
			damageable.append(faction)
	return damageable

## Get all factions allied with the given faction
## 
## [b]faction:[/b] Faction to check allies for
## 
## [b]Returns:[/b] Array of faction names that are allied
## 
## [b]Usage:[/b]
## [codeblock]
## var allies = FactionManager.get_allied_factions("player")
## print("Player allies: ", allies)
## 
## # Count allies
## print("Player has ", allies.size(), " allies")
## [/codeblock]
func get_allied_factions(faction: String) -> Array[String]:
	var allies: Array[String] = []
	for other_faction in _registered_factions:
		if is_ally(faction, other_faction):
			allies.append(other_faction)
	return allies

## Get all factions that are enemies of the given faction
## 
## [b]faction:[/b] Faction to check enemies for
## 
## [b]Returns:[/b] Array of faction names that are enemies
## 
## [b]Usage:[/b]
## [codeblock]
## var enemies = FactionManager.get_enemy_factions("player")
## print("Player enemies: ", enemies)
## 
## # Count enemies
## print("Player has ", enemies.size(), " enemies")
## [/codeblock]
func get_enemy_factions(faction: String) -> Array[String]:
	var enemies: Array[String] = []
	for other_faction in _registered_factions:
		if is_enemy(faction, other_faction):
			enemies.append(other_faction)
	return enemies

## Create a faction group
## 
## Makes all factions in the group allied with each other.
## 
## [b]faction_names:[/b] Array of faction names to group together
## [b]group_name:[/b] Optional name for the group (for debugging)
## 
## [b]Usage:[/b]
## [codeblock]
## # Create a group of allied factions
## var allies = ["player", "ally", "mercenary"]
## FactionManager.create_faction_group(allies, "player_allies")
## 
## # Create a group without name
## FactionManager.create_faction_group(["faction1", "faction2", "faction3"])
## [/codeblock]
func create_faction_group(faction_names: Array[String], group_name: String = "") -> void:
	for i in range(faction_names.size()):
		for j in range(i + 1, faction_names.size()):
			set_relationship(faction_names[i], faction_names[j], Relationship.ALLY)
			set_relationship(faction_names[j], faction_names[i], Relationship.ALLY)

	if group_name != "":
		print("FactionManager: Created faction group '%s' with %d factions" % [group_name, faction_names.size()])

## Declare war between two factions
## 
## Makes two factions enemies and also makes their allies enemies of each other.
## This creates a cascading effect where allied factions also become enemies.
## 
## [b]faction_a:[/b] First faction
## [b]faction_b:[/b] Second faction
## 
## [b]Usage:[/b]
## [codeblock]
## # Declare war between major factions
## FactionManager.declare_war("player", "enemy")
## 
## # This will also make player allies enemies of enemy allies
## [/codeblock]
func declare_war(faction_a: String, faction_b: String) -> void:
	set_relationship(faction_a, faction_b, Relationship.ENEMY)
	set_relationship(faction_b, faction_a, Relationship.ENEMY)

	# Make allies of faction_a enemies of faction_b and vice versa
	var allies_a: Array[String] = get_allied_factions(faction_a)
	var allies_b: Array[String] = get_allied_factions(faction_b)

	for ally_a in allies_a:
		for ally_b in allies_b:
			set_relationship(ally_a, ally_b, Relationship.ENEMY)
			set_relationship(ally_b, ally_a, Relationship.ENEMY)

	print("FactionManager: War declared between '%s' and '%s'" % [faction_a, faction_b])

## Reset all faction relationships
## 
## Clears all custom relationships and restores default ones.
## This is useful for resetting the game state or starting fresh.
## 
## [b]Usage:[/b]
## [codeblock]
## # Reset all relationships
## FactionManager.reset_relationships()
## 
## # Now all factions are back to default relationships
## [/codeblock]
func reset_relationships() -> void:
	_relationships.clear()
	_initialize_default_relationships()

	print("FactionManager: All faction relationships reset")

## Debug: Print current faction relationships
## 
## Prints all faction relationships to the console for debugging.
## 
## [b]Usage:[/b]
## [codeblock]
## # Print all relationships
## FactionManager.debug_print_relationships()
## 
## # Useful for debugging faction issues
## if debug_mode:
##     FactionManager.debug_print_relationships()
## [/codeblock]
func debug_print_relationships() -> void:
	print("=== FACTION RELATIONSHIPS ===")
	for faction_a in _registered_factions:
		for faction_b in _registered_factions:
			if faction_a != faction_b:
				var relationship: Relationship = get_relationship(faction_a, faction_b)
				var rel_name: String = Relationship.keys()[relationship]
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
