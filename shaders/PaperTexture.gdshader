shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.784, 0.722, 0.596, 1.0);
uniform float grain_intensity : hint_range(0.0, 0.15) = 0.05;
uniform float stain_scale : hint_range(1.0, 30.0) = 10.0;
uniform float stain_intensity : hint_range(0.0, 0.15) = 0.04;
uniform float fiber_scale : hint_range(10.0, 200.0) = 100.0;
uniform float fiber_intensity : hint_range(0.0, 0.1) = 0.03;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.2;
uniform float edge_darken : hint_range(0.0, 0.3) = 0.08;

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    vec3 col = base_color.rgb;

    // Paper fiber grain
    float grain = hash(uv * 1200.0) * grain_intensity;
    col += grain - (grain_intensity * 0.5);

    // Directional fiber streaks — horizontal like real paper
    float fiber_h = sin(uv.y * fiber_scale * 6.28 + hash(vec2(floor(uv.y * fiber_scale), 0.0)) * 6.28) * 0.5 + 0.5;
    col += (fiber_h - 0.5) * fiber_intensity;

    // Age stains and foxing spots
    float stain = value_noise(uv * stain_scale);
    stain += value_noise(uv * stain_scale * 2.7) * 0.5;
    stain += value_noise(uv * stain_scale * 6.0) * 0.25;
    stain /= 1.75;
    col += (stain - 0.5) * stain_intensity;

    // Foxing spots — small dark splotches like aged paper
    float fox = value_noise(uv * 40.0);
    fox = smoothstep(0.72, 0.78, fox);
    col -= fox * 0.03;

    // Edge darkening — darker toward all four edges like aged paper
    float edge_x = smoothstep(0.0, 0.15, uv.x) * smoothstep(0.0, 0.15, 1.0 - uv.x);
    float edge_y = smoothstep(0.0, 0.15, uv.y) * smoothstep(0.0, 0.15, 1.0 - uv.y);
    col -= (1.0 - edge_x * edge_y) * edge_darken;

    // Vignette
    vec2 center_dist = uv - vec2(0.5);
    float vignette = 1.0 - dot(center_dist, center_dist) * vignette_strength * 2.0;
    col *= vignette;

    COLOR = vec4(col, base_color.a);
}