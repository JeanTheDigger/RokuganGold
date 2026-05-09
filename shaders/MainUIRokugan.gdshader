shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float grain_amount : hint_range(0.0, 0.15) = 0.04;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_radius : hint_range(0.0, 2.0) = 0.7;
uniform float aberration : hint_range(0.0, 3.0) = 0.0;
uniform float flicker_speed : hint_range(0.0, 5.0) = 0.5;
uniform float flicker_intensity : hint_range(0.0, 0.05) = 0.02;

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // Sample the screen
    vec3 col = textureLod(screen_texture, uv, 0.0).rgb;

    // Subtle chromatic aberration (optional — set to 0 to disable)
    if (aberration > 0.0) {
        vec2 offset = (uv - 0.5) * aberration * 0.001;
        col.r = textureLod(screen_texture, uv + offset, 0.0).r;
        col.b = textureLod(screen_texture, uv - offset, 0.0).b;
    }

    // Film grain — shifts over time so it's not static
    float grain = hash(uv * 500.0 + TIME * 3.0);
    col += (grain - 0.5) * grain_amount;

    // Candlelight flicker
    float flicker = 1.0 + sin(TIME * flicker_speed * 6.28) * flicker_intensity;
    flicker += sin(TIME * flicker_speed * 2.1 * 6.28) * flicker_intensity * 0.5;
    col *= flicker;

    // Vignette
    vec2 center_dist = uv - vec2(0.5);
    float dist = length(center_dist);
    float vignette = smoothstep(vignette_radius, vignette_radius - 0.4, dist);
    col *= mix(1.0 - vignette_strength, 1.0, vignette);

    COLOR = vec4(col, 1.0);
}