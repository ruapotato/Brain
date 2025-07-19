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
@onready var ear_worm = $ear_worm
@onready var brain_light = $brain_light
var beat_times = []
var current_beat_accuracy: float = 0.0
var next_beat_index: int = 0
var default_worm = preload("res://music/brain.wav") # Make sure your music file is here

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
@onready var mesh = $mesh # This should be your brain model
@onready var hurt_sound = $sounds/hurt
@onready var jump_sound = $sounds/jump
@onready var land_sound = $sounds/land
@onready var attack_sound_good = $sounds/attack_good # Sound for on-beat attack
@onready var attack_sound_bad = $sounds/attack_bad   # Sound for off-beat attack

# Get the gravity from project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

#shit for the UI
var root
var UI
var UI_ear_power

# --- Initialization ---
func _ready():
	root = get_parent()
	UI = root.find_child("UI")
	UI_ear_power = UI.find_child("ear_power")
	# Set up camera and mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#cam_piv.top_level = true
	#cam_piv.position = global_position

	# --- Load the beat map and start the music ---
	if ear_worm:
		load_beat_map(default_worm.resource_path)
		play_worm(default_worm)
	else:
		print("ERROR: AudioStreamPlayer node 'ear_worm' is not assigned!")


func update_ui():
	UI_ear_power.value = current_beat_accuracy * 100
	if current_beat_accuracy > .9:
		brain_light.light_energy = 3
	else:
		brain_light.light_energy = .1

func _process(delta: float) -> void:
	update_ui()
# --- Main Game Loop ---
func _physics_process(delta):
	# Always calculate the potential attack accuracy based on the beat map.
	if ear_worm and ear_worm.playing:
		update_beat_accuracy()

	# Handle core physics (gravity, landing, etc.)
	handle_basic_physics(delta)
	
	# Process player controls for movement and actions
	handle_movement_controls(delta)
	
	# Update timers
	update_timers(delta)
	
	# Apply final movement
	move_and_slide()

# --- Input Handling ---
func _unhandled_input(event):
	# Mouse look
	if event is InputEventMouseMotion:
		cam_piv.rotate_y(-event.relative.x * 0.005)
		camera_arm.rotate_x(-event.relative.y * 0.005)
		camera_arm.rotation.x = clamp(camera_arm.rotation.x, -PI/2.1, PI/2.1)

	# Jump input
	if event.is_action_pressed("jump"):
		if is_on_floor() or coyote_timer > 0:
			perform_jump()
		else:
			jump_buffer_timer = JUMP_BUFFER_TIME

	# Attack input
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
		
		# Rotate mesh to face movement direction
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
	
	# *** RHYTHM MECHANIC INTEGRATION ***
	# Check the beat accuracy to determine the attack's quality.
	if current_beat_accuracy > 0.75: # Threshold for a "good" hit
		print("ON-BEAT SWIPE! Accuracy: ", current_beat_accuracy)
		attack_sound_good.play()
		# --- TODO: Trigger your powerful, wide-arc attack animation/effect here ---
	else:
		print("Off-beat swipe. Accuracy: ", current_beat_accuracy)
		attack_sound_bad.play()
		# --- TODO: Trigger your weak, small fizzle effect here ---

func take_damage(knockback_direction: Vector3):
	if is_invulnerable:
		return
	
	hurt_sound.play()
	is_invulnerable = true
	damage_invulnerability_timer = DAMAGE_INVULNERABILITY_TIME
	velocity = knockback_direction * KNOCKBACK_FORCE
	velocity.y = jump_velocity * 0.5 # Pop up slightly when hit
	action_state = ActionState.HURT

# --- Rhythmic Logic (from original script) ---

func load_beat_map(audio_path: String):
	beat_times.clear()
	var beat_map_path = audio_path.get_base_dir() + "/" + audio_path.get_file().get_basename() + ".beats"
	
	if not FileAccess.file_exists(beat_map_path):
		print("Beat map not found! Expected at: ", beat_map_path)
		return

	var file = FileAccess.open(beat_map_path, FileAccess.READ)
	while not file.eof_reached():
		var line = file.get_line()
		if not line.is_empty():
			beat_times.append(line.to_float())
	file.close()
	print("Loaded ", beat_times.size(), " beats.")

func play_worm(this_slappable: AudioStream):
	next_beat_index = 0
	ear_worm.stream = this_slappable
	ear_worm.play()

func update_beat_accuracy():
	if beat_times.is_empty():
		current_beat_accuracy = 0.0
		return

	var song_position = ear_worm.get_playback_position()
	
	while next_beat_index < beat_times.size() and beat_times[next_beat_index] < song_position:
		next_beat_index += 1

	var prev_beat_time = 0.0
	if next_beat_index > 0:
		prev_beat_time = beat_times[next_beat_index - 1]
	
	var next_beat_time = beat_times[-1]
	if next_beat_index < beat_times.size():
		next_beat_time = beat_times[next_beat_index]
		
	var offset = min(song_position - prev_beat_time, next_beat_time - song_position)
	var interval = next_beat_time - prev_beat_time
	
	if interval == 0:
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
