extends Control

var _enemy_scene: PackedScene
var _spawned_enemies: Array[Node] = []

@onready var spawn_button: Button = $SpawnEnemyButton
@onready var despawn_button: Button = $DespawnEnemiesButton

func _ready() -> void:
	# Load enemy scene
	_enemy_scene = preload("res://EnemyAI/BaseEnemy.tscn")
	
	# Connect buttons
	spawn_button.pressed.connect(_on_spawn_enemy_pressed)
	despawn_button.pressed.connect(_on_despawn_enemies_pressed)
	
	print("EnemyDemo: Ready!")

func _on_spawn_enemy_pressed() -> void:
	print("EnemyDemo: Spawn button pressed!")
	
	# Create enemy instance
	var enemy = _enemy_scene.instantiate()
	
	# Spawn position
	var jitter := Vector2(randi() % 41 - 20, randi() % 41 - 20)
	enemy.global_position = Vector2(500, 300) + jitter
	
	# Add to scene
	get_tree().current_scene.add_child(enemy)
	_spawned_enemies.append(enemy)
	
	print("EnemyDemo: Enemy spawned! Total: ", _spawned_enemies.size())

func _on_despawn_enemies_pressed() -> void:
	print("EnemyDemo: Despawn button pressed!")
	
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_spawned_enemies.clear()
	
	print("EnemyDemo: Despawned all enemies")