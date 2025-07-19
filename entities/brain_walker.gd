# This script controls a 3D character that uses rhythmic attacks.
# It merges a complex state machine with the beat-matching logic.
extends CharacterBody3D

# --- Player Movement Variables ---
@export var speed = 5.0
@export var jump_velocity = 6.0
@onready var legs = $mesh/legs
const ACCELERATION = 30.0
const FRICTION = 60.0
const ROTATION_SPEED = 20.0
const KNOCKBACK_FORCE = 8.0

# --- State Machine ---
enum ActionState { IDLE, WALK, JUMP, ATTACK, HURT }
var action_state = ActionState.IDLE

# --- Rhythm & Beat Variables ---
@export_range(0.1, 1.0) var hittable_window_ratio: float = 0.6 # Percentage of the beat interval that is hittable
@onready var ear_worm = $ear_worm
@onready var brain_light = $brain_light
var beat_times = []
var hit_beat_indices: Array = [] # Tracks indices of beats that have been successfully hit
var current_beat_accuracy: float = 0.0 # This will now represent the "power" for the UI
var last_hit_judgment: String = "Miss" # Stores the result of the last attack
var next_beat_index: int = 0
var default_worm = preload("res://music/brain.wav")

# --- Timing Window Ratios (relative to the dynamic hittable window) ---
const PERFECT_RATIO = 0.25 # Perfect window is 25% of the hittable window
const GREAT_RATIO = 0.50   # Great window is 50% of the hittable window
const GOOD_RATIO = 1.00    # Good window is 100% of the hittable window

# --- Attack Properties ---
const PERFECT_SWIPE_RADIUS = 8.0
const PERFECT_SWIPE_POWER = 1.0
const GREAT_SWIPE_RADIUS = 6.0
const GREAT_SWIPE_POWER = 0.7
const GOOD_SWIPE_RADIUS = 4.0
const GOOD_SWIPE_POWER = 0.4

# --- Timers & Buffers ---
const JUMP_BUFFER_TIME = 0.1
const COYOTE_TIME = 0.1
const DAMAGE_INVULNERABILITY_TIME = 0.8
var jump_buffer_timer = 0.0
var coyote_timer = 0.0
var damage_invulnerability_timer = 0.0
var was_on_floor = false
var is_invulnerable = false

# --- Node References ---
@onready var cam_piv = $piv
@onready var camera_arm = $piv/SpringArm3D
@onready var mesh = $mesh
@onready var hurt_sound = $sounds/hurt
@onready var jump_sound = $sounds/jump
@onready var land_sound = $sounds/land
@onready var attack_sound_good = $sounds/attack_good
@onready var attack_sound_bad = $sounds/attack_bad
@onready var psychic_swipe_area = $mesh/psychic_swipe_area
@onready var swipe_vfx = $mesh/swipe_vfx # VFX node for the swipe

# Get the gravity from project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- UI References ---
var root
var UI
var UI_ear_power

# --- Initialization ---
func _ready():
	root = get_parent()
	UI = root.find_child("UI")
	UI_ear_power = UI.find_child("ear_power")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Load the beat map and start the music
	load_beat_map(default_worm.resource_path)
	play_worm(default_worm)


func update_ui():
	# The UI power bar will now reflect the general "on-beat" feeling.
	UI_ear_power.value = current_beat_accuracy * 100
	if current_beat_accuracy > .9:
		brain_light.light_energy = 3
	else:
		brain_light.light_energy = .1

func _process(delta: float) -> void:
	update_ui()
	
	# This function still runs to give the player a general sense of the beat for the UI
	if ear_worm and ear_worm.playing:
		update_beat_accuracy_for_visuals()

# --- Main Game Loop ---
func _physics_process(delta):
	handle_basic_physics(delta)
	handle_movement_controls(delta)
	update_timers(delta)
	move_and_slide()

# --- Input Handling ---
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		cam_piv.rotate_y(-event.relative.x * 0.005)
		camera_arm.rotate_x(-event.relative.y * 0.005)
		camera_arm.rotation.x = clamp(camera_arm.rotation.x, -PI/2.1, PI/2.1)

	if event.is_action_pressed("jump"):
		if is_on_floor() or coyote_timer > 0:
			perform_jump()
		else:
			jump_buffer_timer = JUMP_BUFFER_TIME

	if event.is_action_pressed("attack"):
		perform_psychic_swipe()


# --- Core Logic Functions ---

func handle_basic_physics(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		if was_on_floor:
			coyote_timer = COYOTE_TIME
	else:
		if not was_on_floor:
			land_sound.play()
		if jump_buffer_timer > 0.0:
			perform_jump()
			jump_buffer_timer = 0.0
	was_on_floor = is_on_floor()

func handle_movement_controls(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = Vector3(input_dir.x, 0.0, input_dir.y).normalized().rotated(Vector3.UP, cam_piv.rotation.y)
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		var target_angle = atan2(direction.x, direction.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, delta * ROTATION_SPEED)
		
		if is_on_floor():
			action_state = ActionState.WALK
			legs.animate_legs(delta, Vector3(velocity.x, 0, velocity.z).length() * .1)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		if is_on_floor():
			action_state = ActionState.IDLE
			legs.animate_legs(delta, 0)

# --- Action Functions ---

func perform_jump():
	if is_on_floor() or coyote_timer > 0:
		jump_sound.play()
		velocity.y = jump_velocity
		action_state = ActionState.JUMP
		coyote_timer = 0

func perform_psychic_swipe():
	action_state = ActionState.ATTACK
	
	var judgment = get_hit_judgment()
	last_hit_judgment = judgment
	
	var swipe_radius = 0.0
	var swipe_power = 0.0
	
	match judgment:
		"Perfect":
			print("PERFECT SWIPE!")
			attack_sound_good.play()
			swipe_radius = PERFECT_SWIPE_RADIUS
			swipe_power = PERFECT_SWIPE_POWER
			trigger_swipe_vfx(swipe_radius, Color.GOLD)
		"Great":
			print("GREAT SWIPE!")
			attack_sound_good.play()
			swipe_radius = GREAT_SWIPE_RADIUS
			swipe_power = GREAT_SWIPE_POWER
			trigger_swipe_vfx(swipe_radius, Color.CYAN)
		"Good":
			print("Good swipe.")
			attack_sound_good.play()
			swipe_radius = GOOD_SWIPE_RADIUS
			swipe_power = GOOD_SWIPE_POWER
			trigger_swipe_vfx(swipe_radius, Color.WHITE)
		_: # Miss
			print("Off-beat swipe... Miss.")
			attack_sound_bad.play()
			# Optionally, trigger a small "fizzle" effect for a miss
			# trigger_swipe_vfx(1.0, Color.GRAY) 
			return

	# --- Find and damage enemies within the swipe radius ---
	var bodies = psychic_swipe_area.get_overlapping_bodies()
	for body in bodies:
		if body == self: # Don't hit yourself
			continue
		
		if global_position.distance_to(body.global_position) <= swipe_radius:
			var knockback_direction = (body.global_position - global_position).normalized()
			if "damage" in body:
				body.damage(swipe_power, knockback_direction)


func trigger_swipe_vfx(radius: float, color: Color):
	# Set the color of the particles
	var material = swipe_vfx.process_material as ParticleProcessMaterial
	material.color = color
	
	# Reset and restart the particle system
	swipe_vfx.scale = Vector3.ONE * radius
	swipe_vfx.restart()


func take_damage(knockback_direction: Vector3):
	if is_invulnerable:
		return
	
	hurt_sound.play()
	is_invulnerable = true
	damage_invulnerability_timer = DAMAGE_INVULNERABILITY_TIME
	velocity = knockback_direction * KNOCKBACK_FORCE
	velocity.y = jump_velocity * 0.5
	action_state = ActionState.HURT

# --- Rhythmic Logic ---

func load_beat_map(audio_path: String):
	beat_times.clear()
	var beat_map_path = audio_path.get_base_dir() + "/" + audio_path.get_file().get_basename() + ".beats"
	
	var file = FileAccess.open(beat_map_path, FileAccess.READ)
	while not file.eof_reached():
		var line = file.get_line()
		if not line.is_empty():
			beat_times.append(line.to_float())
	file.close()

func play_worm(this_slappable: AudioStream):
	next_beat_index = 0
	hit_beat_indices.clear() # Reset hit tracking for the new song
	ear_worm.stream = this_slappable
	ear_worm.play()

# --- REVISED: This function now uses dynamic windows and prevents spamming ---
func get_hit_judgment() -> String:
	if beat_times.size() < 2 or not ear_worm.playing:
		return "Miss"

	var song_position = ear_worm.get_playback_position()
	
	# --- Find the closest beat and its index ---
	var closest_beat_index = -1
	var min_diff = 1000.0 # Start with a large number
	var search_start = max(0, next_beat_index - 5)
	var search_end = min(beat_times.size(), next_beat_index + 5)
	for i in range(search_start, search_end):
		var diff = abs(beat_times[i] - song_position)
		if diff < min_diff:
			min_diff = diff
			closest_beat_index = i

	# If no beat is reasonably close, it's a miss.
	if closest_beat_index == -1:
		return "Miss"
		
	# --- Check if this beat has already been hit ---
	if closest_beat_index in hit_beat_indices:
		return "Miss"

	# --- Calculate the dynamic hittable window for this specific beat ---
	var current_beat_time = beat_times[closest_beat_index]
	var prev_beat_time
	var next_beat_time

	# Handle edge cases for the first and last beats
	if closest_beat_index == 0: # First beat
		prev_beat_time = current_beat_time - (beat_times[1] - current_beat_time)
	else:
		prev_beat_time = beat_times[closest_beat_index - 1]

	if closest_beat_index == beat_times.size() - 1: # Last beat
		next_beat_time = current_beat_time + (current_beat_time - prev_beat_time)
	else:
		next_beat_time = beat_times[closest_beat_index + 1]
	
	var interval = (next_beat_time - prev_beat_time) / 2.0
	var hittable_window_half_size = interval * hittable_window_ratio

	# --- Check if the hit is outside the dynamic hittable window ---
	var time_difference = abs(current_beat_time - song_position)
	if time_difference > hittable_window_half_size:
		return "Miss"
	
	# --- Determine judgment based on ratios of the hittable window ---
	var judgment = "Miss"
	var perfect_window = hittable_window_half_size * PERFECT_RATIO
	var great_window = hittable_window_half_size * GREAT_RATIO
	
	if time_difference <= perfect_window:
		judgment = "Perfect"
	elif time_difference <= great_window:
		judgment = "Great"
	else:
		judgment = "Good"
		
	# --- Register the successful hit and return judgment ---
	hit_beat_indices.append(closest_beat_index)
	return judgment


# --- This function is for the continuous UI bar ---
func update_beat_accuracy_for_visuals():
	if beat_times.is_empty():
		current_beat_accuracy = 0.0
		return

	var song_position = ear_worm.get_playback_position()
	
	# Advance the beat index
	while next_beat_index < beat_times.size() and beat_times[next_beat_index] < song_position:
		# When we pass a beat that we didn't hit, remove it from future consideration
		# to prevent it from being hit late.
		if not next_beat_index in hit_beat_indices:
			hit_beat_indices.append(next_beat_index)
		next_beat_index += 1

	if next_beat_index >= beat_times.size():
		current_beat_accuracy = 0.0
		return

	var prev_beat_time = 0.0
	if next_beat_index > 0:
		prev_beat_time = beat_times[next_beat_index - 1]
	
	var next_beat_time = beat_times[next_beat_index]
		
	var offset = min(song_position - prev_beat_time, next_beat_time - song_position)
	var interval = next_beat_time - prev_beat_time
	
	if interval <= 0.001:
		current_beat_accuracy = 1.0
		return
		
	var accuracy = 1.0 - (offset / (interval / 2.0))
	current_beat_accuracy = clamp(accuracy, 0.0, 1.0)


# --- Timer Updates ---

func update_timers(delta):
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if coyote_timer > 0:
		coyote_timer -= delta
	if damage_invulnerability_timer > 0:
		damage_invulnerability_timer -= delta
		if damage_invulnerability_timer <= 0:
			is_invulnerable = false
