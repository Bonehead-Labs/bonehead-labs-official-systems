extends CharacterBody2D

var chasing: bool = false
var target: Node2D = null

func _physics_process(delta: float) -> void:
	if chasing and target:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * 100.0
		move_and_slide()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()

func _on_sight_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		print("Player entered sight area!")
		chasing = true
		target = body

func _on_sight_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		print("Player left sight area!")
		chasing = false
		target = null
