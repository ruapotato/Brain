# PsychicSwipeVFX.gd
# This script controls the lifecycle of the swipe effect using _process.
# It manually updates its position and shader, then frees itself.
extends Node3D

## The total distance the effect will travel along its local forward (-Z) axis.
@export var travel_distance: float = 1.5

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Animation constants
const TOTAL_LIFETIME: float = 0.3
const DISSOLVE_DELAY: float = 0.1

# State variables for tracking animation progress
var _is_animating: bool = false
var _elapsed_time: float = 0.0
var _start_position: Vector3
var _target_position: Vector3

func _ready():
	# Disable processing by default. It's only needed when the animation is active.
	set_process(false)
	
	# To prevent multiple VFX from animating the same material, we create a unique instance.
	# This is crucial if you spawn more than one swipe at a time.
	if mesh_instance.material_override:
		mesh_instance.material_override = mesh_instance.material_override.duplicate()
	else:
		mesh_instance.material_override = mesh_instance.get_active_material(0).duplicate()


func _process(delta: float):
	if not _is_animating:
		return

	# Increment the timer
	_elapsed_time += delta

	# --- Update Position ---
	# Calculate movement progress (0.0 to 1.0) over the total lifetime
	var move_progress = clamp(_elapsed_time / TOTAL_LIFETIME, 0.0, 1.0)
	# Linearly interpolate the position from its start to the target
	self.position = _start_position.lerp(_target_position, move_progress)

	# --- Update Dissolve Shader ---
	# Calculate how far into the dissolve we are (it starts after a delay)
	var time_into_dissolve = _elapsed_time - DISSOLVE_DELAY
	var dissolve_duration = TOTAL_LIFETIME - DISSOLVE_DELAY
	# Calculate dissolve progress (0.0 to 1.0)
	var dissolve_progress = clamp(time_into_dissolve / dissolve_duration, 0.0, 1.0)
	# Update the shader uniform
	mesh_instance.get_active_material(0).set_shader_parameter("dissolve_progress", dissolve_progress)

	# --- Cleanup ---
	# When the lifetime is over, remove the node from the scene
	if _elapsed_time >= TOTAL_LIFETIME:
		queue_free()


# Call this function to start the VFX animation.
func start_animation():
	# Initialize state variables for the animation
	_elapsed_time = 0.0
	_start_position = self.position
	_target_position = self.position - self.transform.basis.y * travel_distance
	_is_animating = true
	
	# Enable the _process function to run the animation
	set_process(true)
