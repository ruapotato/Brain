# This script controls a 3D character that can jump based on rhythm.
# It loads a pre-analyzed beat map file (.beats) for perfect, drift-free timing.

extends CharacterBody3D

# --- Player Movement Variables ---
@export var speed = 5.0
@export var jump_velocity = 9.0 # Increased for more satisfying "good" jumps
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Rhythm & Beat Variables ---
var beat_times = [] # This will be populated from the .beats file.
var current_beat_accuracy: float = 0.0
var next_beat_index: int = 0 # An index to efficiently find the next beat

# --- UI Variables ---
var root
var UI
var UI_ear_power

# --- Node References ---
@onready var ear_worm: AudioStreamPlayer = $ear_worm
@onready var camera = $piv/SpringArm3D/Camera3D
@onready var camera_piv = $piv
@onready var camera_arm = $piv/SpringArm3D

# Preload the default music file. Can be .wav or .ogg
var default_worm = preload("res://music/brain.wav")


# This function is called once when the node enters the scene tree.
func _ready() -> void:
	# --- Get UI References ---
	root = get_parent()
	UI = root.find_child("UI")
	if UI:
		UI_ear_power = UI.find_child("ear_power")
	if not UI_ear_power:
		print("UI node 'ear_power' not found. The UI will not update.")

	# --- Load the pre-analyzed beat map ---
	load_beat_map(default_worm.resource_path)

	# Start playing the default song.
	play_worm(default_worm)


# This function runs every frame, tied to the physics engine.
func _physics_process(delta) -> void:
	# Continuously calculate the potential jump accuracy based on the perfect beat map.
	update_beat_accuracy()

	# Update the UI element continuously to show potential jump power.
	if UI_ear_power:
		UI_ear_power.value = current_beat_accuracy * 100
	
	# --- Basic Character Movement ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = (jump_velocity / 2) + (jump_velocity / 2 * current_beat_accuracy)
		print("Jumped with accuracy: ", current_beat_accuracy)

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		# Using lerp for smoother deceleration.
		velocity.x = lerp(velocity.x, 0.0, speed * delta)
		velocity.z = lerp(velocity.z, 0.0, speed * delta)

	move_and_slide()


# --- Custom Functions ---

# Loads beat timestamps from a .beats file.
func load_beat_map(audio_path: String):
	beat_times.clear()
	# Construct the .beats file path from the audio file path.
	var beat_map_path = audio_path.get_base_dir() + "/" + audio_path.get_file().get_basename() + ".beats"
	
	if not FileAccess.file_exists(beat_map_path):
		print("Beat map not found! Expected at: " + beat_map_path)
		print("Please run the Python beat_mapper.py script on your audio file.")
		return

	var file = FileAccess.open(beat_map_path, FileAccess.READ)
	print("Loading beat map from: ", beat_map_path)
	
	# Read each line from the file, convert it to a float, and add it to our beat_times array.
	while not file.eof_reached():
		var line = file.get_line()
		if not line.is_empty():
			beat_times.append(line.to_float())
	
	file.close()
	print("Successfully loaded ", beat_times.size(), " beats.")


# Assigns a new audio stream and plays it.
func play_worm(this_slappable: AudioStream) -> void:
	next_beat_index = 0
	ear_worm.stream = this_slappable
	ear_worm.play()


# Calculates jump accuracy based on the pre-analyzed, perfect beat map.
func update_beat_accuracy():
	if beat_times.is_empty():
		current_beat_accuracy = 0.0
		return

	var song_position = ear_worm.get_playback_position()
	
	# Advance our beat index to keep it close to the current song position.
	while next_beat_index < beat_times.size() and beat_times[next_beat_index] < song_position:
		next_beat_index += 1

	# Get the time of the previous and next beats from our perfect map.
	var prev_beat_time = 0.0
	if next_beat_index > 0:
		prev_beat_time = beat_times[next_beat_index - 1]
	
	var next_beat_time = beat_times[-1] # Default to last beat if we're at the end
	if next_beat_index < beat_times.size():
		next_beat_time = beat_times[next_beat_index]
		
	# Calculate the offset from the closest beat.
	var offset = min(song_position - prev_beat_time, next_beat_time - song_position)
	var interval = next_beat_time - prev_beat_time
	
	if interval == 0:
		current_beat_accuracy = 1.0 # Should only happen on a perfect hit
		return
		
	# Normalize the offset to a 0-1 accuracy value.
	var accuracy = 1.0 - (offset / (interval / 2.0))
	current_beat_accuracy = clamp(accuracy, 0.0, 1.0)
