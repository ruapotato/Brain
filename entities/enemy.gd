# enemy.gd
# A simple enemy script. Attach this to your enemy CharacterBody3D scene.
extends CharacterBody3D

@export var health = 1.0
@export var knockback_strength = 50.0

# --- AI Properties ---
@export var speed = 2.2
@export var notice_distance = 50.0
@export var knockback_damping = 5.0 # How quickly knockback fades

var player
var root
var knockback = Vector3.ZERO # Stores the current knockback vector

func _ready():
	root = get_parent().get_parent()
	player = root.find_child("player")

func _physics_process(delta):
	# Apply damping to the knockback so it wears off over time
	knockback = knockback.lerp(Vector3.ZERO, knockback_damping * delta)
	
	# Calculate AI movement separately
	var ai_velocity = Vector3.ZERO
	var direction_to_player = (player.global_position - global_position).normalized()
	if global_position.distance_to(player.global_position) < notice_distance:
		ai_velocity = direction_to_player * speed
	
	# Combine AI movement with the current knockback and set the final velocity
	velocity = ai_velocity + knockback
		
	move_and_slide()

# This function is called by the player's psychic swipe.
func damage(power: float, direction: Vector3):
	health -= power
	print("Enemy took ", power, " damage, health is now ", health)
	
	# Add the attack's force to our knockback vector
	knockback = direction * knockback_strength * power
	
	if health <= 0:
		die()

func die():
	print("Enemy has been defeated!")
	# You can add explosion effects or other death animations here.
	queue_free()
