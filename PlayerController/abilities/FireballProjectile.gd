class_name FireballProjectile
extends Node2D

## Simple fireball projectile that moves in a direction and deals damage

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage: float = 25.0
var lifetime: float = 3.0

func _ready():
	# Wait a frame for children to be added
	await get_tree().process_frame
	
	var area = get_node_or_null("Area2D")
	if area != null and not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)

func _process(delta):
	global_position += direction * speed * delta
	lifetime -= delta
	
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
