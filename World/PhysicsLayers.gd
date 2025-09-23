extends Resource
class_name PhysicsLayers

## Central definition of physics layers for the game.

const LAYER_PLAYER: int = 0
const LAYER_ENEMIES: int = 1
const LAYER_PROJECTILES: int = 2
const LAYER_INTERACTABLES: int = 3
const LAYER_HAZARDS: int = 4
const LAYER_DESTRUCTIBLES: int = 5
const LAYER_WORLD: int = 6
const LAYER_TRIGGERS: int = 7

const LAYER_NAMES: Dictionary = {
    LAYER_PLAYER: "Player",
    LAYER_ENEMIES: "Enemies",
    LAYER_PROJECTILES: "Projectiles",
    LAYER_INTERACTABLES: "Interactables",
    LAYER_HAZARDS: "Hazards",
    LAYER_DESTRUCTIBLES: "Destructibles",
    LAYER_WORLD: "World",
    LAYER_TRIGGERS: "Triggers"
}

const COLLISION_MATRIX: Dictionary = {
    # Player collisions
    LAYER_PLAYER: [LAYER_WORLD, LAYER_INTERACTABLES, LAYER_HAZARDS, LAYER_DESTRUCTIBLES],

    # Enemy collisions
    LAYER_ENEMIES: [LAYER_WORLD, LAYER_INTERACTABLES, LAYER_HAZARDS, LAYER_DESTRUCTIBLES, LAYER_PLAYER],

    # Projectile collisions
    LAYER_PROJECTILES: [LAYER_WORLD, LAYER_HAZARDS, LAYER_DESTRUCTIBLES, LAYER_ENEMIES, LAYER_PLAYER],

    # Interactable collisions (minimal)
    LAYER_INTERACTABLES: [LAYER_PLAYER, LAYER_ENEMIES],

    # Hazard collisions (affect everything)
    LAYER_HAZARDS: [LAYER_PLAYER, LAYER_ENEMIES, LAYER_PROJECTILES, LAYER_DESTRUCTIBLES],

    # Destructible collisions
    LAYER_DESTRUCTIBLES: [LAYER_PLAYER, LAYER_ENEMIES, LAYER_PROJECTILES, LAYER_HAZARDS],

    # World collisions (everything collides with world)
    LAYER_WORLD: [LAYER_PLAYER, LAYER_ENEMIES, LAYER_PROJECTILES, LAYER_INTERACTABLES, LAYER_HAZARDS, LAYER_DESTRUCTIBLES],

    # Trigger collisions (detection only)
    LAYER_TRIGGERS: [LAYER_PLAYER, LAYER_ENEMIES, LAYER_PROJECTILES]
}

static func get_layer_name(layer_index: int) -> String:
    return LAYER_NAMES.get(layer_index, "Unknown")

static func get_layer_index(layer_name: String) -> int:
    for index in LAYER_NAMES:
        if LAYER_NAMES[index] == layer_name:
            return index
    return -1

static func should_collide(layer_a: int, layer_b: int) -> bool:
    var collisions_a: Array = COLLISION_MATRIX.get(layer_a, [])
    var collisions_b: Array = COLLISION_MATRIX.get(layer_b, [])

    # Check both directions since collision should be symmetric
    return collisions_a.has(layer_b) or collisions_b.has(layer_a)

static func get_collision_mask_for_layer(layer_index: int) -> int:
    var mask: int = 0
    var collisions: Array = COLLISION_MATRIX.get(layer_index, [])

    for collision_layer in collisions:
        mask |= (1 << collision_layer)

    return mask

static func apply_physics_settings(node: Node) -> void:
    if not node:
        return

    match node.get_class():
        "CharacterBody2D", "CharacterBody3D", "RigidBody2D", "RigidBody3D", "StaticBody2D", "StaticBody3D":
            _apply_body_settings_static(node)
        "Area2D", "Area3D":
            _apply_area_settings_static(node)
        "CollisionShape2D", "CollisionShape3D":
            _apply_shape_settings_static(node)

static func _apply_body_settings_static(body: Node) -> void:
    # Set collision layer and mask based on body type or name
    var layer_index: int = LAYER_WORLD  # Default to world layer

    if "player" in body.name.to_lower():
        layer_index = LAYER_PLAYER
    elif "enemy" in body.name.to_lower():
        layer_index = LAYER_ENEMIES
    elif "projectile" in body.name.to_lower():
        layer_index = LAYER_PROJECTILES
    elif "interactable" in body.name.to_lower():
        layer_index = LAYER_INTERACTABLES
    elif "hazard" in body.name.to_lower():
        layer_index = LAYER_HAZARDS
    elif "destructible" in body.name.to_lower():
        layer_index = LAYER_DESTRUCTIBLES

    if body.has_method("set_collision_layer"):
        body.call("set_collision_layer", (1 << layer_index))

    if body.has_method("set_collision_mask"):
        body.call("set_collision_mask", get_collision_mask_for_layer(layer_index))

static func _apply_area_settings_static(area: Node) -> void:
    # Areas typically detect multiple layers
    var mask: int = 0

    # Most areas should detect players and enemies
    mask |= (1 << LAYER_PLAYER)
    mask |= (1 << LAYER_ENEMIES)

    # Some areas might need to detect projectiles
    if "perception" in area.name.to_lower() or "detection" in area.name.to_lower():
        mask |= (1 << LAYER_PROJECTILES)

    if area.has_method("set_collision_mask"):
        area.call("set_collision_mask", mask)

static func _apply_shape_settings_static(_shape: Node) -> void:
    # Shapes inherit layer/mask from their parent bodies/areas
    pass
