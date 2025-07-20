# enemy_manager.gd
# This node dynamically spawns and manages waves of enemies.
# It spawns enemies in clumps just outside the player's immediate area
# and despawns them if they get too far away.
extends Node3D

@export var enemy_scene: PackedScene

# --- Spawning Properties ---
@export_category("Spawning")
# The maximum number of enemies allowed in the world at one time.
@export var max_enemies = 50
# The distance from the player where new clumps will spawn.
@export var spawn_distance = 30.0
# The minimum number of enemies in a single clump.
@export var clump_size_min = 3
# The maximum number of enemies in a single clump.
@export var clump_size_max = 8
# How spread out the enemies are within a clump.
@export var clump_spread = 5.0

# --- Culling Properties ---
@export_category("Culling")
# The distance at which enemies are considered "too far" and will be removed.
@export var despawn_distance = 120.0

var player

func _ready():
	# Find the player node. Assumes it's a child of the parent (the main scene root).
	player = get_parent().find_child("player")

	# Create a timer to periodically run the main logic.
	# Checking once a second is efficient and effective for this kind of manager.
	var timer = Timer.new()
	timer.wait_time = 1.0 # Check once per second.
	timer.timeout.connect(_on_update_timer_timeout)
	add_child(timer)
	timer.start()

func _on_update_timer_timeout():
	if not is_instance_valid(player):
		return

	var current_enemies = []
	# Build a list of all current enemy nodes.
	for child in get_children():
		# This check is safer than assuming all children are enemies.
		if child is CharacterBody3D:
			current_enemies.append(child)

	var player_pos = player.global_position

	# --- 1. Despawn distant enemies ---
	for enemy in current_enemies:
		if player_pos.distance_to(enemy.global_position) > despawn_distance:
			enemy.queue_free() # Remove enemy to make room for new ones.

	# --- 2. Spawn new clumps if needed ---
	# Recalculate count after potential despawns.
	var enemy_count = get_child_count() - 1 # Subtract 1 for the Timer node
	if enemy_count < max_enemies:
		spawn_clump()

func spawn_clump():
	if not enemy_scene or not is_instance_valid(player):
		return

	# --- Calculate the center point for the new clump ---
	# 1. Get a random direction vector.
	var direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	# 2. Position the clump center at 'spawn_distance' from the player.
	var clump_center = player.global_position + Vector3(direction.x, 0, direction.y) * spawn_distance

	# --- Spawn the enemies within the clump ---
	var spawn_count = randi_range(clump_size_min, clump_size_max)
	for i in spawn_count:
		# Don't spawn more than the max allowed number of enemies.
		if (get_child_count() - 1) >= max_enemies:
			break
			
		var enemy_instance = enemy_scene.instantiate()

		# Get a small random offset from the clump center.
		var offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0, clump_spread)
		var spawn_pos = clump_center + offset
		
		add_child(enemy_instance)
		enemy_instance.global_position = spawn_pos
