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
@export var source_path: NodePath  # Path to source node (for editor use)
var source: Node = null  # Runtime reference to source node
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
	if p_source:
		source_path = p_source.get_path()
		source_name = p_source.name

## Create a damage instance
## 
## Factory method for creating damage instances with proper initialization.
## This is the recommended way to create damage instances.
## 
## [b]p_amount:[/b] Damage amount (positive for damage)
## [b]p_type:[/b] Type of damage (default: PHYSICAL)
## [b]p_source:[/b] Node that caused the damage (optional)
## 
## [b]Returns:[/b] New DamageInfo instance
## 
## [b]Usage:[/b]
## [codeblock]
## # Create basic damage
## var damage = DamageInfo.create_damage(25.0, DamageInfo.DamageType.FIRE)
## 
## # Create damage with source
## var damage = DamageInfo.create_damage(50.0, DamageInfo.DamageType.PHYSICAL, player)
## [/codeblock]
static func create_damage(p_amount: float, p_type: DamageType = DamageType.PHYSICAL, p_source: Node = null) -> DamageInfo:
	var damage: DamageInfo = DamageInfo.new()
	damage.amount = p_amount
	damage.type = p_type
	damage.source = p_source
	if p_source:
		damage.source_path = p_source.get_path()
		damage.source_name = p_source.name
	return damage

## Create a healing instance
## 
## Factory method for creating healing instances. Healing uses the same
## system as damage but with positive amounts and HEALING type.
## 
## [b]p_amount:[/b] Healing amount (positive for healing)
## [b]p_source:[/b] Node that caused the healing (optional)
## 
## [b]Returns:[/b] New DamageInfo instance configured for healing
## 
## [b]Usage:[/b]
## [codeblock]
## # Create basic healing
## var healing = DamageInfo.create_healing(30.0)
## 
## # Create healing with source
## var healing = DamageInfo.create_healing(50.0, healer_node)
## [/codeblock]
static func create_healing(p_amount: float, p_source: Node = null) -> DamageInfo:
	var healing: DamageInfo = DamageInfo.new()
	healing.amount = p_amount
	healing.type = DamageType.HEALING
	healing.source = p_source
	if p_source:
		healing.source_path = p_source.get_path()
		healing.source_name = p_source.name
	return healing

## Check if this damage info represents healing
## 
## Determines if this instance represents healing rather than damage.
## Healing can be identified by type or negative amount.
## 
## [b]Returns:[/b] true if this is healing, false if damage
## 
## [b]Usage:[/b]
## [codeblock]
## if damage_info.is_healing():
##     print("This will heal the target")
## else:
##     print("This will damage the target")
## [/codeblock]
func is_healing() -> bool:
	return type == DamageType.HEALING or amount < 0.0

## Get the effective amount of damage or healing
## 
## Returns the actual amount that will be applied. For damage,
## this is positive. For healing, this is also positive (healing
## is handled by the HEALING type, not negative amounts).
## 
## [b]Returns:[/b] Effective amount to apply
## 
## [b]Usage:[/b]
## [codeblock]
## var effective = damage_info.get_effective_amount()
## if damage_info.is_healing():
##     target.health += effective
## else:
##     target.health -= effective
## [/codeblock]
func get_effective_amount() -> float:
	return amount

## Create a copy with modified amount
## 
## Creates a new DamageInfo instance with the same properties
## except for the amount, which is set to the new value.
## 
## [b]new_amount:[/b] New damage/healing amount
## 
## [b]Returns:[/b] New DamageInfo instance with modified amount
## 
## [b]Usage:[/b]
## [codeblock]
## # Create damage with different amount
## var heavy_damage = base_damage.with_amount(100.0)
## [/codeblock]
func with_amount(new_amount: float) -> DamageInfo:
	var copy: DamageInfo = duplicate() as DamageInfo
	copy.amount = new_amount
	return copy

## Create a copy with modified type
## 
## Creates a new DamageInfo instance with the same properties
## except for the type, which is set to the new value.
## 
## [b]new_type:[/b] New damage type
## 
## [b]Returns:[/b] New DamageInfo instance with modified type
## 
## [b]Usage:[/b]
## [codeblock]
## # Convert physical damage to fire damage
## var fire_damage = physical_damage.with_type(DamageInfo.DamageType.FIRE)
## [/codeblock]
func with_type(new_type: DamageType) -> DamageInfo:
	var copy: DamageInfo = duplicate() as DamageInfo
	copy.type = new_type
	return copy

## Create a copy with knockback properties
## 
## Creates a new DamageInfo instance with the same properties
## plus knockback force and duration.
## 
## [b]force:[/b] Knockback force vector
## [b]duration:[/b] Knockback duration in seconds (default: 0.2)
## 
## [b]Returns:[/b] New DamageInfo instance with knockback
## 
## [b]Usage:[/b]
## [codeblock]
## # Add knockback to damage
## var knockback_damage = base_damage.with_knockback(Vector2(100, -50), 0.3)
## [/codeblock]
func with_knockback(force: Vector2, duration: float = 0.2) -> DamageInfo:
	var copy: DamageInfo = duplicate() as DamageInfo
	copy.knockback_force = force
	copy.knockback_duration = duration
	return copy

## Create a copy with additional status effect
## 
## Creates a new DamageInfo instance with the same properties
## plus an additional status effect to apply.
## 
## [b]effect_name:[/b] Name of the status effect to add
## 
## [b]Returns:[/b] New DamageInfo instance with status effect
## 
## [b]Usage:[/b]
## [codeblock]
## # Add poison effect to damage
## var poison_damage = base_damage.with_status_effect("poison")
## 
## # Chain multiple effects
## var complex_damage = base_damage.with_status_effect("burn").with_status_effect("stun")
## [/codeblock]
func with_status_effect(effect_name: String) -> DamageInfo:
	var copy: DamageInfo = duplicate() as DamageInfo
	copy.status_effects = status_effects.duplicate()
	copy.status_effects.append(effect_name)
	return copy

## Create a copy with additional metadata
## 
## Creates a new DamageInfo instance with the same properties
## plus additional metadata for custom damage processing.
## 
## [b]key:[/b] Metadata key
## [b]value:[/b] Metadata value
## 
## [b]Returns:[/b] New DamageInfo instance with metadata
## 
## [b]Usage:[/b]
## [codeblock]
## # Add custom metadata
## var special_damage = base_damage.with_metadata("element", "ice")
## var boss_damage = base_damage.with_metadata("is_boss_attack", true)
## [/codeblock]
func with_metadata(key: String, value: Variant) -> DamageInfo:
	var copy: DamageInfo = duplicate() as DamageInfo
	copy.metadata = metadata.duplicate()
	copy.metadata[key] = value
	return copy

## Get a human-readable description
## 
## Creates a formatted string describing this damage/healing instance.
## Useful for UI display, debugging, and logging.
## 
## [b]Returns:[/b] Formatted description string
## 
## [b]Usage:[/b]
## [codeblock]
## # Display damage info
## print(damage_info.get_description())  # "25.0 damage (FIRE)"
## print(healing_info.get_description())  # "30.0 healing (HEALING)"
## [/codeblock]
func get_description() -> String:
	var type_name: String = DamageType.keys()[type]
	var action: String = "healing" if is_healing() else "damage"
	var amount_str: String = String.num(abs(amount), 1)
	return "%s %s (%s)" % [amount_str, action, type_name]

## Validate the damage info
## 
## Checks if this DamageInfo instance is valid for use.
## Validates required fields and warns about potential issues.
## 
## [b]Returns:[/b] true if valid, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Validate before applying damage
## if damage_info.validate():
##     health_component.take_damage(damage_info)
## else:
##     print("Invalid damage info")
## [/codeblock]
func validate() -> bool:
	if amount == 0.0:
		push_warning("DamageInfo: amount is zero")
		return false
	return true
