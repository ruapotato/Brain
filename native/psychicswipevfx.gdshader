// A simple shader for a glowing, dissolving energy slash.
shader_type spatial;

// 'unshaded' makes it ignore lighting, perfect for a magical effect.
// 'cull_disabled' makes the quad visible from both sides.
// 'blend_add' creates a bright, energetic look when overlapping.
render_mode unshaded, cull_disabled, blend_add;

// Uniforms are parameters you can control from the Inspector or a script.
uniform vec4 tint : source_color = vec4(0.5, 1.0, 1.0, 1.0); // The color of the swipe
uniform sampler2D noise_texture : hint_default_black;      // A noise texture for the dissolve effect
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0; // How much of the slash has dissolved

void fragment() {
    // We'll use the U (horizontal) coordinate to shape the slash.
    float u = UV.x;

    // Create a smooth falloff at the edges of the quad.
    float fade = smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.9, 1.0, u));

    // Use the noise texture to create a dissolving effect.
    // 'step' creates a hard edge. Pixels with noise values less than 'dissolve_progress' will be cut.
    float dissolve_value = texture(noise_texture, UV).r;
    float dissolve_mask = 1.0 - step(dissolve_value, dissolve_progress);

    // Set the final color and alpha
    ALBEDO = tint.rgb;
    ALPHA = tint.a * fade * dissolve_mask;
}