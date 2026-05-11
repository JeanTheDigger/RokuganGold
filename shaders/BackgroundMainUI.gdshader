shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.078, 0.067, 0.063, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.941, 0.902, 0.831, 1.0);
uniform float grain_intensity : hint_range(0.0, 0.15) = 0.025;
uniform float stain_scale : hint_range(1.0, 30.0) = 12.0;
uniform float stain_intensity : hint_range(0.0, 0.15) = 0.03;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.15;
uniform float ripple_speed : hint_range(0.0, 2.0) = 0.9;
uniform float ripple_strength : hint_range(0.0, 0.03) = 0.01;
uniform float ripple_scale : hint_range(1.0, 20.0) = 4.0;
uniform float ripple_tint : hint_range(0.0, 0.3) = 0.15;
uniform float wave_visible : hint_range(0.0, 0.1) = 0.08;

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

    // Flowing ripple distortion
    float t = TIME * ripple_speed;
    float ripple_x = sin(uv.y * ripple_scale * 6.28 + t * 2.1) * ripple_strength;
    float ripple_y = cos(uv.x * ripple_scale * 6.28 + t * 1.7) * ripple_strength;
    ripple_x += sin(uv.y * ripple_scale * 3.0 + t * 3.3) * ripple_strength * 0.5;
    ripple_y += cos(uv.x * ripple_scale * 4.1 + t * 2.8) * ripple_strength * 0.5;
    vec2 distorted_uv = uv + vec2(ripple_x, ripple_y);

    vec3 col = base_color.rgb;

    // Fine grain
    float grain = hash(distorted_uv * 800.0) * grain_intensity;
    col += grain - (grain_intensity * 0.5);

    // Visible wave pattern — flowing lines instead of dot grid
    float wave1 = sin(distorted_uv.y * 25.0 + t * 1.5 + sin(distorted_uv.x * 8.0) * 0.5);
    float wave2 = sin(distorted_uv.x * 18.0 + t * 1.1 + sin(distorted_uv.y * 6.0) * 0.4);
    float wave3 = sin((distorted_uv.x + distorted_uv.y) * 12.0 + t * 0.8);
    float waves = (wave1 + wave2 * 0.5 + wave3 * 0.3) / 1.8;
    col += waves * wave_visible;

    // Aging stains
    float stain = value_noise(distorted_uv * stain_scale);
    stain += value_noise(distorted_uv * stain_scale * 2.3) * 0.5;
    stain += value_noise(distorted_uv * stain_scale * 5.1) * 0.25;
    stain /= 1.75;
    col += (stain - 0.5) * stain_intensity;

    // Candlelight caustic
    float caustic = value_noise(distorted_uv * 3.0 + t * 0.5);
    caustic *= value_noise(distorted_uv * 5.0 - t * 0.3);
    col += caustic * 0.012;

    // Ripple color tint — warm shimmer where waves peak
    float ripple_amount = (waves + 1.0) / 2.0;
    col = mix(col, ripple_color.rgb, ripple_amount * ripple_tint);

    // Vignette
    vec2 center_dist = uv - vec2(0.5);
    float vignette = 1.0 - dot(center_dist, center_dist) * vignette_strength * 2.0;
    col *= vignette;

    COLOR = vec4(col, base_color.a);
}