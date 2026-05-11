shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.05, 0.04, 0.03, 1.0);
uniform vec4 mist_color : source_color = vec4(0.78, 0.66, 0.43, 0.6);
uniform float mist_speed : hint_range(0.0, 1.0) = 0.15;
uniform float mist_density : hint_range(0.0, 0.3) = 0.08;
uniform float mist_scale : hint_range(1.0, 10.0) = 3.0;
uniform float swirl_strength : hint_range(0.0, 3.0) = 1.5;
uniform float inner_radius : hint_range(0.0, 0.5) = 0.15;
uniform float outer_radius : hint_range(0.2, 1.0) = 0.5;
uniform float particle_intensity : hint_range(0.0, 0.5) = 0.15;
uniform float particle_density : hint_range(10.0, 80.0) = 40.0;
uniform float sparkle_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float sparkle_density : hint_range(20.0, 150.0) = 80.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

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

vec2 rotate(vec2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5);
    vec2 from_center = uv - center;
    float dist = length(from_center);
    float t = TIME * mist_speed;

    vec3 col = bg_color.rgb;

    // Ring mask
    float ring = smoothstep(inner_radius, inner_radius + 0.1, dist);
    ring *= smoothstep(outer_radius, outer_radius - 0.15, dist);

    // Swirling distortion
    float swirl_angle = dist * swirl_strength + t * 2.0;
    vec2 swirled = rotate(from_center, swirl_angle) + center;

    // Mist layer 1
    float mist1 = value_noise(swirled * mist_scale + vec2(t * 0.3, t * 0.2));
    mist1 += value_noise(swirled * mist_scale * 1.7 + vec2(-t * 0.2, t * 0.4)) * 0.5;
    mist1 /= 1.5;

    // Mist layer 2 — counter-rotating
    vec2 swirled2 = rotate(from_center, -swirl_angle * 0.7 + 1.0) + center;
    float mist2 = value_noise(swirled2 * mist_scale * 1.3 + vec2(t * 0.15, -t * 0.25));
    mist2 += value_noise(swirled2 * mist_scale * 2.1 + vec2(t * 0.35, t * 0.1)) * 0.5;
    mist2 /= 1.5;

    float mist = (mist1 + mist2) / 2.0;
    mist *= ring;
    col = mix(col, mist_color.rgb, mist * mist_density);

    // Medium particles — drifting embers
    float p1 = value_noise(swirled * particle_density + vec2(t, t * 0.7));
    p1 = smoothstep(0.78, 0.82, p1);

    float p2 = value_noise(swirled2 * particle_density * 0.8 + vec2(-t * 0.6, t * 1.1));
    p2 = smoothstep(0.80, 0.84, p2);

    float particles = (p1 + p2) * ring;
    col += mist_color.rgb * particles * particle_intensity;

    // Tiny sparkles — smooth drifting pinpoints
    float s1 = value_noise(swirled * sparkle_density + vec2(t * 0.5, t * 0.3));
    s1 = smoothstep(0.85, 0.90, s1);

    float s2 = value_noise(swirled2 * sparkle_density * 1.2 + vec2(-t * 0.4, t * 0.6));
    s2 = smoothstep(0.86, 0.91, s2);

    float s3 = value_noise(swirled * sparkle_density * 0.7 + vec2(t * 0.7, -t * 0.35));
    s3 = smoothstep(0.87, 0.92, s3);

    // Sparkles pulse gently
    float twinkle1 = sin(t * 8.0 + s1 * 30.0) * 0.5 + 0.5;
    float twinkle2 = sin(t * 6.5 + s2 * 25.0) * 0.5 + 0.5;
    float twinkle3 = sin(t * 9.2 + s3 * 35.0) * 0.5 + 0.5;

    float sparkles = (s1 * twinkle1 + s2 * twinkle2 + s3 * twinkle3) * ring;
    col += vec3(1.0, 0.9, 0.7) * sparkles * sparkle_intensity;

    // Subtle pulsing glow on ring edges
    float pulse = sin(t * 3.0) * 0.5 + 0.5;
    float glow_ring = smoothstep(inner_radius + 0.05, inner_radius, dist);
    glow_ring += smoothstep(outer_radius - 0.05, outer_radius, dist);
    col += mist_color.rgb * glow_ring * pulse * 0.02;

    // Fine grain
    float grain = hash(uv * 800.0) * 0.02;
    col += grain - 0.01;

    // Vignette
    vec2 cd = uv - center;
    float vignette = 1.0 - dot(cd, cd) * vignette_strength * 2.0;
    col *= max(vignette, 0.0);

    COLOR = vec4(col, 1.0);
}