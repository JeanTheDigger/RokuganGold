shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.608, 0.478, 0.800, 1.0);
uniform float circle_radius : hint_range(0.1, 0.5) = 0.45;
uniform float border_thickness : hint_range(0.001, 0.03) = 0.006;
uniform float glow_size : hint_range(0.01, 0.3) = 0.2;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.8;
uniform float pulse_amount : hint_range(0.0, 0.3) = 0.1;
uniform float inner_fill_opacity : hint_range(0.0, 0.4) = 0.15;
uniform float bloom_intensity : hint_range(0.0, 1.0) = 0.35;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);

    float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
    float radius = circle_radius * pulse;

    float circle_edge = abs(dist - radius);

    float border = smoothstep(border_thickness, border_thickness * 0.3, circle_edge);

    float glow = exp(-circle_edge * circle_edge / (glow_size * glow_size * 0.01)) * glow_intensity;

    float inner_mask = step(dist, radius);
    float inner = inner_fill_opacity * inner_mask;

    float bloom = (1.0 - smoothstep(0.0, 0.7, dist)) * bloom_intensity * pulse;

    float intensity = border + glow + inner + bloom;
    vec3 col = glow_color.rgb * intensity;
    float alpha = clamp(intensity, 0.0, 1.0);

    COLOR = vec4(col, alpha);
}