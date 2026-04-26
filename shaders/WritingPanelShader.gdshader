shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float scanline_intensity = 0.02;   // reduced
uniform float vignette_strength = 0.08;    // softer
uniform float flicker_strength = 0.005;    // extremely subtle

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 col = texture(screen_tex, uv);

    // Very subtle scanlines
    float scan = sin(uv.y * 1000.0) * scanline_intensity;
    col.rgb -= scan;

    // Soft vignette (less aggressive)
    float dist = distance(uv, vec2(0.5));
    col.rgb *= 1.0 - dist * vignette_strength;

    // Tiny brightness variation (barely visible)
    col.rgb *= 1.0 + sin(TIME * 1.5) * flicker_strength;

    COLOR = col;
}
