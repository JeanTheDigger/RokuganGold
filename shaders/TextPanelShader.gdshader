shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float scanline_intensity = 0.04;
uniform float vignette_strength = 0.12;
uniform float chroma_offset = 0.0008;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 col = texture(screen_tex, uv);

    // Subtle scanlines
    float scan = sin(uv.y * 1200.0) * scanline_intensity;
    col.rgb -= scan;

    // Very subtle chromatic shift
    float r = texture(screen_tex, uv + vec2(chroma_offset, 0.0)).r;
    float g = texture(screen_tex, uv).g;
    float b = texture(screen_tex, uv - vec2(chroma_offset, 0.0)).b;
    col.rgb = vec3(r, g, b);

    // Soft vignette
    float dist = distance(uv, vec2(0.5));
    col.rgb *= 1.0 - dist * vignette_strength;

    COLOR = col;
}
