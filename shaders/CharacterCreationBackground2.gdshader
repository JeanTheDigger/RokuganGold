shader_type canvas_item;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 base_color : source_color = vec4(0.078, 0.067, 0.063, 1.0);
uniform vec4 air_color : source_color = vec4(0.4, 0.54, 0.85, 1.0);
uniform vec4 earth_color : source_color = vec4(0.545, 0.608, 0.290, 1.0);
uniform vec4 fire_color : source_color = vec4(0.851, 0.400, 0.282, 1.0);
uniform vec4 water_color : source_color = vec4(0.290, 0.545, 0.608, 1.0);
uniform vec4 spirit_color : source_color = vec4(0.608, 0.478, 0.800, 1.0);
uniform vec4 gold_color : source_color = vec4(0.78, 0.66, 0.35, 1.0);
uniform float flow_speed : hint_range(0.0, 0.5) = 0.1;
uniform float stream_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float stream_scale : hint_range(1.0, 10.0) = 2.0;
uniform float gold_intensity : hint_range(0.0, 0.3) = 0.3;
uniform float gold_scale : hint_range(1.0, 10.0) = 2.5;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.2;

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
    float t = TIME * flow_speed;
    vec3 col = base_color.rgb;

    // Gold ambient
    float gold1 = value_noise(uv * gold_scale + vec2(t * 0.2, t * 0.15));
    float gold2 = value_noise(uv * gold_scale * 1.6 + vec2(-t * 0.15, t * 0.25));
    float gold = (gold1 + gold2) / 2.0;
    col += gold_color.rgb * gold * gold_intensity;

    // Air
    float air = value_noise(uv * stream_scale + vec2(t, t * 0.5));
    float air_weight = max(0.0, 1.0 - length(uv - vec2(0.1, 0.15)) * 1.5);
    col += air_color.rgb * air * air_weight * stream_intensity;

    // Earth
    float earth = value_noise(uv * stream_scale + vec2(t * 0.5, -t * 0.7));
    float earth_weight = max(0.0, 1.0 - length(uv - vec2(0.1, 0.85)) * 1.5);
    col += earth_color.rgb * earth * earth_weight * stream_intensity;

    // Fire
    float fire = value_noise(uv * stream_scale + vec2(-t * 0.8, t * 0.6));
    float fire_weight = max(0.0, 1.0 - length(uv - vec2(0.9, 0.15)) * 1.5);
    col += fire_color.rgb * fire * fire_weight * stream_intensity;

    // Water
    float water = value_noise(uv * stream_scale + vec2(-t * 0.6, -t * 0.5));
    float water_weight = max(0.0, 1.0 - length(uv - vec2(0.9, 0.85)) * 1.5);
    col += water_color.rgb * water * water_weight * stream_intensity;

    // Spirit (Void element)
    float spirit_pulse = 0.8 + 0.2 * sin(t * 8.0);
    float spirit_stream = value_noise(uv * stream_scale + vec2(t * 0.3, -t * 0.4));
    float spirit_weight = max(0.0, 1.0 - length(uv - vec2(0.5, 0.5)) * 2.0);
    col += spirit_color.rgb * spirit_stream * spirit_weight * stream_intensity * spirit_pulse;

    // Vignette
    vec2 cd = uv - vec2(0.5);
    float vignette = 1.0 - dot(cd, cd) * vignette_strength * 2.0;
    col *= vignette;

    COLOR = vec4(col * opacity, opacity);
}