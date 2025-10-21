shader_type canvas_item;

// Uniforms: Parâmetros que podemos ajustar no editor
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Núcleo branco
uniform vec4 glow_color : source_color = vec4(0.2, 0.8, 1.0, 0.8); // Brilho azul
uniform float core_width : hint_range(0.0, 1.0) = 0.2; // Largura do núcleo (0.0 a 1.0)
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.6; // Força do tremor
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0; // Velocidade do tremor

// Função simples para gerar ruído pseudo-aleatório
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    // UV.y vai de 0.0 (topo da linha) a 1.0 (base da linha).
    // Calculamos a distância do centro (0.0 no centro, 1.0 nas bordas).
    float dist_from_center = abs(UV.y - 0.5) * 2.0;

    // Interpola entre a cor do núcleo e a cor do brilho.
    // smoothstep cria uma transição suave.
    vec4 base_color = mix(core_color, glow_color, smoothstep(core_width, 1.0, dist_from_center));

    // Calcula o ruído baseado na posição ao longo da linha (UV.x) e no tempo (TIME).
    float noise = rand(vec2(UV.x * 5.0, TIME * flicker_speed)); // Multiplicar UV.x dá mais detalhe ao ruído

    // Aplica a intensidade do tremor ao ruído.
    // 'noise' agora varia entre (1.0 - flicker_intensity) e 1.0.
    noise = mix(1.0 - flicker_intensity, 1.0, noise);

    // Modula o alfa (transparência) da cor base pelo ruído para criar o flicker.
    base_color.a *= noise;

    // A cor final é a cor calculada multiplicada pela cor original do Line2D (vertex color).
    COLOR = base_color * COLOR;
}