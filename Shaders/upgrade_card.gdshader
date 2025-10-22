shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.4);
uniform float shine_progress : hint_range(-1.0, 2.0) = 0.0;
uniform float shine_width : hint_range(0.0, 1.0) = 0.15;

void fragment() {
    vec4 current_color = texture(TEXTURE, UV) * base_color;

    float shine_start = shine_progress - shine_width;
    float shine_end = shine_progress + shine_width;

    float diagonal_pos = UV.x + UV.y;

    if (diagonal_pos > shine_start && diagonal_pos < shine_end) {
        float shine_factor = 1.0 - abs(diagonal_pos - shine_progress) / shine_width;
        current_color.rgb = mix(current_color.rgb, shine_color.rgb, shine_factor * shine_color.a);
    }

    COLOR = current_color;
}