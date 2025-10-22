shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.8, 1.0, 0.8);
uniform float core_width : hint_range(0.0, 1.0) = 0.2;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    float dist_from_center = abs(UV.y - 0.5) * 2.0;

    vec4 base_color = mix(core_color, glow_color, smoothstep(core_width, 1.0, dist_from_center));

    float noise = rand(vec2(UV.x * 5.0, TIME * flicker_speed));

    noise = mix(1.0 - flicker_intensity, 1.0, noise);

    base_color.a *= noise;

    COLOR = base_color * COLOR;
}