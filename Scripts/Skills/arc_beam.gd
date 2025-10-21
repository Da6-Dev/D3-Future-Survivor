extends Area2D

# --- REFERÊNCIAS ATUALIZADAS ---
@onready var tendril_container: Node2D = $TendrilContainer
@onready var crackle_timer: Timer = $CrackleTimer
@onready var collision_shape: CollisionPolygon2D = $BeamCollision

var damage_amount: int = 1
var knockback_strength: float = 100.0

var _hit_cooldown: float = 0.5
var _enemies_on_hit_cooldown: Dictionary = {}
var _pop_tween: Tween

# --- PARÂMETROS DO RAIO ---
var _segments_per_tendril: int = 5 # Mais segmentos = mais detalhe
var _base_jitter: float = 3.0     # Tremor base
var _jitter_variation: float = 2.0 # Variação aleatória no tremor

var _local_p1: Vector2 = Vector2.ZERO
var _local_p2: Vector2 = Vector2.ZERO
var _tendrils: Array[Line2D] = [] # Array para guardar os Line2D

func _ready() -> void:
	# --- ENCONTRA OS TENDRILS ---
	for child in tendril_container.get_children():
		if child is Line2D:
			_tendrils.append(child)
			# Configurações visuais iniciais (podem ser feitas no editor também)
			child.width = 1.0
			child.default_color = Color(0.9, 0.9, 1.0, randf_range(0.7, 0.9)) # Cor/Alfa levemente aleatórios
			# (Adicione Width Curve e End Cap Mode no editor)

	# Desativa tudo no início
	monitoring = false
	collision_shape.disabled = true
	tendril_container.visible = false

	# Conecta os sinais
	area_entered.connect(_on_area_entered)
	crackle_timer.wait_time = 0.05 # 20fps para a animação
	crackle_timer.timeout.connect(_update_tendril_shapes)

# Armazena os pontos finais e atualiza a colisão
func update_beam(pos_a: Vector2, pos_b: Vector2) -> void:
	global_position = (pos_a + pos_b) / 2.0
	_local_p1 = to_local(pos_a)
	_local_p2 = to_local(pos_b)

	# Atualiza a Colisão (polígono reto, igual antes)
	var collision_width = 8.0 # Aumentar um pouco a largura da colisão
	var normal = (_local_p2 - _local_p1).normalized().orthogonal() * (collision_width / 2.0)
	var polygon_points = PackedVector2Array()
	polygon_points.append(_local_p1 - normal)
	polygon_points.append(_local_p1 + normal)
	polygon_points.append(_local_p2 + normal)
	polygon_points.append(_local_p2 - normal)
	collision_shape.polygon = polygon_points

	# Atualiza os raios VISUAIS (se estiverem ativos)
	if tendril_container.visible:
		_update_tendril_shapes()

# --- FUNÇÃO PRINCIPAL DO "JUICE" ---
# Chamada pelo CrackleTimer para animar TODOS os raios
func _update_tendril_shapes():
	if not tendril_container.visible or _tendrils.is_empty():
		return

	var direction = _local_p2 - _local_p1
	var normal = direction.orthogonal().normalized()

	# Itera por cada Line2D (Tendril)
	for tendril in _tendrils:
		tendril.clear_points()
		tendril.add_point(_local_p1) # Ponto inicial

		# Calcula um tremor ligeiramente diferente para este tendril
		var current_jitter = _base_jitter + randf_range(-_jitter_variation, _jitter_variation)

		# Adiciona pontos irregulares no meio
		for i in range(1, _segments_per_tendril):
			var t = float(i) / _segments_per_tendril
			var mid_pos = _local_p1.lerp(_local_p2, t)
			var offset = randf_range(-current_jitter, current_jitter)
			tendril.add_point(mid_pos + (normal * offset))

		tendril.add_point(_local_p2) # Ponto final

# --- FUNÇÕES DE ATIVAÇÃO ATUALIZADAS ---
func activate() -> void:
	_enemies_on_hit_cooldown.clear()
	monitoring = true
	collision_shape.disabled = false # Colisão ativa
	tendril_container.visible = true # Mostra os raios
	crackle_timer.start()

	if is_instance_valid(_pop_tween):
		_pop_tween.kill()
	_pop_tween = create_tween().set_parallel() # Animações em paralelo

	# Anima o fade-in e talvez um "pop" de largura/jitter para cada tendril
	for tendril in _tendrils:
		tendril.modulate = Color(1,1,1,0) # Começa invisível
		_pop_tween.tween_property(tendril, "modulate:a", tendril.default_color.a, 0.1)
		# Opcional: Animar largura ou jitter aqui também

	# Anima o jitter base (começa mais selvagem e acalma)
	_base_jitter = 8.0
	_pop_tween.tween_property(self, "_base_jitter", 3.0, 0.2)

func deactivate() -> void:
	monitoring = false
	collision_shape.disabled = true
	crackle_timer.stop()

	if is_instance_valid(_pop_tween):
		_pop_tween.kill()
	_pop_tween = create_tween().set_parallel()

	# Anima o fade-out para cada tendril
	for tendril in _tendrils:
		_pop_tween.tween_property(tendril, "modulate:a", 0.0, 0.2)

	# Esconde o container DEPOIS que todos terminarem o fade
	_pop_tween.tween_callback(func():
		tendril_container.visible = false
		for tendril in _tendrils: tendril.clear_points() # Limpa os pontos
	)

# --- Lógica de Dano (Sem mudanças) ---
func _on_area_entered(area: Area2D):
	var target = area.get_owner()
	
	if _enemies_on_hit_cooldown.has(target):
		return

	if target.is_in_group("enemies") and target.has_method("take_damage"):
		var knockback_dir = (target.global_position - global_position).normalized()
		target.take_damage(damage_amount, knockback_dir, knockback_strength)
		
		var hit_timer: SceneTreeTimer = get_tree().create_timer(_hit_cooldown)
		_enemies_on_hit_cooldown[target] = hit_timer
		await hit_timer.timeout
		
		if _enemies_on_hit_cooldown.has(target):
			_enemies_on_hit_cooldown.erase(target)
