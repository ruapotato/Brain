# enemy.gd
# A simple enemy script. Attach this to your enemy CharacterBody3D scene.
extends CharacterBody3D

@export var health = 1.0
@export var knockback_strength = 70.0

# --- AI Properties ---
@export var speed = 2.2
@export var notice_distance = 50.0
@export var knockback_damping = 5.0 # How quickly knockback fades
@export var speed_up_distance = 25.0 # Distance at which the enemy speeds up
@export var speed_up_factor = 1.75   # How much faster the enemy gets
@export var attack_damage = 1
@export var attack_range = .8       # How close the enemy needs to be to attack
@export var attack_cooldown = 1.0    # Time between attacks in seconds

var player
var root
var UI
var UI_kill_count
var knockback = Vector3.ZERO # Stores the current knockback vector
var attack_timer = 0.0       # Cooldown timer for attacks

func _ready():
	root = get_parent().get_parent()
	player = root.find_child("player")
	UI = root.find_child("UI")
	UI_kill_count = UI.find_child("kill_count")
	

func _physics_process(delta):
	# Apply damping to the knockback so it wears off over time
	knockback = knockback.lerp(Vector3.ZERO, knockback_damping * delta)
	
	# --- Movement Logic ---
	var ai_velocity = Vector3.ZERO
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player < notice_distance:
		var direction_to_player = (player.global_position - global_position).normalized()
		var current_speed = speed
		
		if distance_to_player > speed_up_distance:
			current_speed *= speed_up_factor
			
		ai_velocity = direction_to_player * current_speed
	
	velocity = ai_velocity + knockback
	move_and_slide()

	# --- Attack Logic ---
	if attack_timer > 0:
		attack_timer -= delta

	if distance_to_player < attack_range and attack_timer <= 0:
		attack()

func attack():
	print("Enemy attacking player!")
	attack_timer = attack_cooldown
	
	# Call the player's damage function.
	# This assumes your player script has a 'damage(power, direction)' method.
	var direction_to_player = (player.global_position - global_position).normalized()
	player.damage(attack_damage, direction_to_player)

# This function is called by the player's psychic swipe.
func damage(power: float, direction: Vector3):
	health -= power
	print("Enemy took ", power, " damage, health is now ", health)
	
	knockback = direction * knockback_strength * power
	
	if health <= 0:
		die()

func die():
	UI_kill_count.text = str(int(UI_kill_count.text) + 1)
	print("Enemy has been defeated!")
	queue_free()
