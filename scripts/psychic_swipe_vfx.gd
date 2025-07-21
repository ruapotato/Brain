# PsychicSwipeVFX.gd
# This script controls the lifecycle of the swipe effect.
# It tweens the shader parameters and then frees itself.
extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# This function starts the VFX animation. Call this right after you instantiate the scene.
func start_animation():
	# Ensure the material is unique to this instance so tweens don't affect other swipes.
	#mesh_instance.material_override = mesh_instance.material_override.duplicate()

	# A Tween is perfect for animating properties over time.
	var tween = create_tween()
	
	# Animate the "dissolve_progress" uniform in the shader.
	# It will go from 0.0 (fully visible) to 1.0 (fully dissolved) in 0.6 seconds.
	# We'll give it a slight delay so the slash appears for a moment before dissolving.
	tween.tween_property(mesh_instance.get_active_material(0), "shader_parameter/dissolve_progress", 1.0,0.6).from(0.0).set_delay(0.2)

	# Once the tween is finished, we connect it to the queue_free() method.
	# This ensures the VFX scene cleans itself up automatically.
	tween.finished.connect(queue_free)
