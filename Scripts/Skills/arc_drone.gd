extends Node2D

@onready var visual: Node2D = $Visual

# Propriedades configuradas pelo script da habilidade
var bob_frequency: float = 3.0
var bob_amplitude: float = 4.0
var max_squash_amount: float = 0.2
var squash_speed_cap: float = 500.0

# --- LÓGICA DE FLIP REMOVIDA ---
# A variável _last_facing_scale_x foi removida.

func _ready():
	if not visual:
		push_error("Visual do drone não encontrado!")

# Esta é a função chamada pelo script principal 60x por segundo
func update_visual_animations(velocity: Vector2, time: float, index: int, delta: float):
	if not is_instance_valid(visual):
		return

	# --- ANIMAÇÕES SIMPLIFICADAS ---

	# 1. Flutuação (Bobbing)
	# O visual se move para cima e para baixo em seu eixo Y local
	visual.position.y = sin(time * bob_frequency + index * PI) * bob_amplitude
	visual.position.x = 0 # Mantém o visual centrado no nó pai

	# 2. Esticar/Achatar (Squash/Stretch)
	# O visual achata verticalmente e alarga horizontalmente quando se move rápido
	var speed = velocity.length()
	
	# 'squash_y' vai de 1.0 (parado) até (1.0 - max_squash_amount) [e.g., 0.8]
	var squash_y = remap(speed, 0.0, squash_speed_cap, 1.0, 1.0 - max_squash_amount)
	# 'stretch_x' faz o oposto para "conservar o volume"
	var stretch_x = remap(speed, 0.0, squash_speed_cap, 1.0, 1.0 + max_squash_amount)

	# 3. Aplicar Transformações
	# A lógica de flip foi removida daqui.
	var target_scale = Vector2(stretch_x, squash_y)
	
	# Interpola suavemente (lerp) para o novo scale
	visual.scale = visual.scale.lerp(target_scale, delta * 10.0)
