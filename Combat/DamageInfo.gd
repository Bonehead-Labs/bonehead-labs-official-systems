class_name DamageInfo
extends Resource

## Resource containing damage information for combat calculations.
## Used by HealthComponent to process damage and healing.

enum DamageType {
	PHYSICAL,
	MAGICAL,
	FIRE,
	ICE,
	LIGHTNING,
	POISON,
	HEALING,  # Special type for healing amounts
	TRUE      # Bypasses all resistances and modifiers
}

@export var amount: float = 0.0
@export var type: DamageType = DamageType.PHYSICAL
@export var source: Node = null
@export var source_name: String = ""
@export var critical: bool = false
@export var can_be_blocked: bool = true
@export var can_be_dodged: bool = true
@export var knockback_force: Vector2 = Vector2.ZERO
@export var knockback_duration: float = 0.0
@export var status_effects: Array[String] = []  # Names of status effects to apply
@export var metadata: Dictionary = {}  # Additional damage-specific data

func _init(p_amount: float = 0.0, p_type: DamageType = DamageType.PHYSICAL, p_source: Node = null) -> void:
	amount = p_amount
	type = p_type
	source = p_source
	if source:
		source_name = source.name

## Create a damage instance
static func create_damage(p_amount: float, p_type: DamageType = DamageType.PHYSICAL, p_source: Node = null) -> DamageInfo:
	var damage := DamageInfo.new()
	damage.amount = p_amount
	damage.type = p_type
	damage.source = p_source
	if p_source:
		damage.source_name = p_source.name
	return damage

## Create a healing instance
static func create_healing(p_amount: float, p_source: Node = null) -> DamageInfo:
	var healing := DamageInfo.new()
	healing.amount = p_amount
	healing.type = DamageType.HEALING
	healing.source = p_source
	if p_source:
		healing.source_name = p_source.name
	return healing

## Check if this is healing (positive damage of healing type)
func is_healing() -> bool:
	return type == DamageType.HEALING or amount < 0.0

## Get the actual damage/healing amount (positive for damage, negative for healing)
func get_effective_amount() -> float:
	return amount

## Create a copy with modified amount
func with_amount(new_amount: float) -> DamageInfo:
	var copy := duplicate() as DamageInfo
	copy.amount = new_amount
	return copy

## Create a copy with modified type
func with_type(new_type: DamageType) -> DamageInfo:
	var copy := duplicate() as DamageInfo
	copy.type = new_type
	return copy

## Create a copy with knockback
func with_knockback(force: Vector2, duration: float = 0.2) -> DamageInfo:
	var copy := duplicate() as DamageInfo
	copy.knockback_force = force
	copy.knockback_duration = duration
	return copy

## Add a status effect
func with_status_effect(effect_name: String) -> DamageInfo:
	var copy := duplicate() as DamageInfo
	copy.status_effects = status_effects.duplicate()
	copy.status_effects.append(effect_name)
	return copy

## Set metadata
func with_metadata(key: String, value: Variant) -> DamageInfo:
	var copy := duplicate() as DamageInfo
	copy.metadata = metadata.duplicate()
	copy.metadata[key] = value
	return copy

## Get a human-readable description
func get_description() -> String:
	var type_name := DamageType.keys()[type]
	var action := "healing" if is_healing() else "damage"
	var amount_str := String.num(abs(amount), 1)
	return "%s %s (%s)" % [amount_str, action, type_name]

## Validate the damage info
func validate() -> bool:
	if amount == 0.0:
		push_warning("DamageInfo: amount is zero")
		return false
	return true
