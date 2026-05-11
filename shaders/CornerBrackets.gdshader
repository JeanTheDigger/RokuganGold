shader_type canvas_item;

uniform float gleam_speed : hint_range(0.01, 0.5) = 0.08;
uniform vec4 gleam_color : source_color = vec4(0.784, 0.663, 0.431, 1.0);
uniform float gleam_width : hint_range(0.02, 0.2) = 0.06;
uniform float gleam_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float gleam_offset : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    if (tex.a < 0.01) {
        COLOR = tex;
    } else {
        float t = fract(TIME * gleam_speed + gleam_offset);
        float pos = (UV.x + UV.y) / 2.0;
        float dist = abs(pos - t);
        dist = min(dist, 1.0 - dist);

        float glow = smoothstep(gleam_width, 0.0, dist) * gleam_intensity;
        vec3 col = mix(tex.rgb, gleam_color.rgb, glow);

        COLOR = vec4(col, tex.a);
    }
}