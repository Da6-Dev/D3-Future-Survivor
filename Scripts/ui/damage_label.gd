# res://Scenes/UI/damage_label.gd
extends Label

# Configurações da animação
@export var move_speed: float = 100.0
@export var gravity: float = 300.0
@export var lifetime: float = 0.6
@export var fade_start_percent: float = 0.5 # Começa a desaparecer na metade da vida

var velocity: Vector2
var timer: float = 0.0

# Cores
var normal_color: Color = Color.WHITE
var crit_color: Color = Color.RED

func _ready():
	# Define uma velocidade inicial aleatória para um efeito mais "espalhado"
	var random_dir = Vector2(randf_range(-0.5, 0.5), -1.0).normalized()
	velocity = random_dir * move_speed

func setup(amount: int, is_critical: bool, start_global_pos: Vector2):
	text = "%.0f" % amount
	global_position = start_global_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5)) # Leve offset
	timer = 0.0
	
	if is_critical:
		modulate = crit_color
		# (Opcional) Aumenta a escala para dano crítico
		scale = Vector2(1.2, 1.2)
	else:
		modulate = normal_color
		scale = Vector2(1.0, 1.0)

func _process(delta: float):
	timer += delta
	if timer >= lifetime:
		queue_free() # A label se autodestrói
		return

	# Aplica "gravidade" (para fazer o número subir e depois cair)
	velocity.y += gravity * delta
	# Move a label
	global_position += velocity * delta
	
	# Cuida do "Fade" (desaparecer)
	if timer > lifetime * fade_start_percent:
		var fade_duration = lifetime * (1.0 - fade_start_percent)
		var fade_progress = (timer - (lifetime * fade_start_percent)) / fade_duration
		
		var new_color = modulate
		new_color.a = 1.0 - fade_progress # Anima o alpha (transparência)
		modulate = new_color
