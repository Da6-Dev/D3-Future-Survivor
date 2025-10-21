extends BaseAbility

# ... (Todas as @export categories permanecem iguais) ...
@export_category("Arc Drones Parameters")
@export var beam_scene: PackedScene
@export var drone_scene: PackedScene
@export var rotation_speed: float = 1.0
@export var radius: float = 80.0
@export var drone_count: int = 2
@export var knockback_strength: float = 200.0

@export_group("Spring Physics (Movement Juice)")
@export var drone_stiffness: float = 10.0
@export var drone_damping: float = 3.0
@export var drone_separation_strength: float = 8.0

@export_group("Behavior & Animation")
@export var max_chase_radius: float = 450.0
@export var bob_frequency: float = 3.0
@export var bob_amplitude: float = 4.0
@export var max_squash_amount: float = 0.2
@export var squash_speed_cap: float = 500.0

@export_group("Wander Behavior (Idle Juice)")
@export var wander_strength: float = 5.0
@export var wander_change_speed: float = 2.0

@onready var pivot: Node2D = $Pivot
@onready var drone_container: Node2D = $DroneContainer
@onready var beam_container: Node2D = $BeamContainer

var _drones: Array[Node2D] = []
var _beams: Array[Area2D] = []
var _time: float = 0.0
var _target_find_timer: Timer
var _wander_noise = FastNoiseLite.new()

# --- MUDANÇA DE LÓGICA DE ALVO ---
# Substituímos o Array _targets por um Dicionário,
# para dar persistência de alvo a cada drone.
var _drone_targets: Dictionary = {} # Key: drone, Value: target

func _ability_ready() -> void:
	if not beam_scene: push_error("A cena da Viga (beam_scene) não foi definida!")
	if not drone_scene: push_error("A cena do Drone (drone_scene) não foi definida!")

	_generate_drones_and_beams()
	on_deactivated.connect(_on_attack_finished)
	
	_target_find_timer = Timer.new()
	_target_find_timer.wait_time = 0.5
	_target_find_timer.timeout.connect(_find_targets)
	add_child(_target_find_timer)
	_target_find_timer.start()
	
	_wander_noise.seed = randi()
	_wander_noise.frequency = 0.1

func _physics_process(delta: float) -> void:
	# --- SALVAGUARDA DE SINCRONIZAÇÃO ---
	# Se o número de drones instanciados não bate com a contagem esperada...
	if _drones.size() != drone_count:
		push_warning("Desincronização detectada! Regenerando drones...")
		regenerate_drones() # ...força a regeneração agora!
		# Se ainda assim não bater (erro na regeneração?), sai para evitar crash.
		if _drones.size() != drone_count:
			return 
	# ------------------------------------
			
	_time += delta
	pivot.rotation += rotation_speed * delta
	
	var home_angle_step = TAU / drone_count
	
	for i in range(_drones.size()): # Itera pelo tamanho REAL do array
		var drone = _drones[i] 
		var velocity: Vector2 = drone.get_meta("velocity", Vector2.ZERO)

		# ... (Resto da lógica de movimento da mola e wander) ...
		var home_angle = pivot.rotation + (i * home_angle_step)
		var home_pos = global_position + Vector2(radius, 0).rotated(home_angle)
		var target_pos: Vector2 = home_pos
		var is_chasing = false
		var current_target = _drone_targets.get(drone)

		if is_instance_valid(current_target):
			if global_position.distance_to(current_target.global_position) <= max_chase_radius:
				target_pos = current_target.global_position
				is_chasing = true
			else:
				_drone_targets[drone] = null
		
		var acceleration = (target_pos - drone.global_position) * drone_stiffness
		if not is_chasing:
			var wander_x = _wander_noise.get_noise_2d(_time * wander_change_speed, i * 10.0)
			var wander_y = _wander_noise.get_noise_2d(_time * wander_change_speed, i * 10.0 + 100.0)
			var wander_force = Vector2(wander_x, wander_y).normalized() * wander_strength
			acceleration += wander_force

		velocity += acceleration * delta
		var current_damping = drone_damping * 0.5 if is_chasing else drone_damping
		velocity = velocity.lerp(Vector2.ZERO, delta * current_damping)
		drone.global_position += velocity * delta
		drone.set_meta("velocity", velocity)

		if drone.has_method("update_visual_animations"):
			drone.update_visual_animations(velocity, _time, i, delta)
	
	# Atualiza as vigas
	# --- CORREÇÃO IMPORTANTE AQUI TAMBÉM ---
	# Garante que o número de vigas também esteja sincronizado
	if _beams.size() != drone_count:
		push_warning("Desincronização de vigas detectada!")
		# Se as vigas estiverem dessincronizadas, é melhor não tentar atualizá-las
		# até a próxima regeneração.
		return 
		
	for i in range(_beams.size()): # Itera pelo tamanho REAL do array
		var beam = _beams[i]
		# A linha original que causava o crash:
		# var drone_a = _drones[i]
		# var drone_b = _drones[(i + 1) % drone_count] <-- Problema aqui
		
		# --- LÓGICA MAIS SEGURA ---
		# Garante que os índices existam antes de acessá-los
		if i < _drones.size():
			var drone_a = _drones[i]
			var next_drone_index = (i + 1) % _drones.size() # Usa o tamanho REAL do array
			if next_drone_index < _drones.size():
				var drone_b = _drones[next_drone_index]
				beam.update_beam(drone_a.global_position, drone_b.global_position)
			else:
				# Isso não deveria acontecer com a lógica de módulo, mas é uma segurança extra
				push_warning("Índice de drone_b inválido!")
		else:
			push_warning("Índice de drone_a inválido!")

func _generate_drones_and_beams() -> void:
	for child in drone_container.get_children(): child.queue_free()
	for child in beam_container.get_children(): child.queue_free()
	_drones.clear()
	_beams.clear()
	_drone_targets.clear() # Limpa o dicionário

	for i in range(drone_count):
		var drone: Node2D = drone_scene.instantiate()
		
		if drone.has_method("update_visual_animations"):
			drone.bob_frequency = self.bob_frequency
			drone.bob_amplitude = self.bob_amplitude
			drone.max_squash_amount = self.max_squash_amount
			drone.squash_speed_cap = self.squash_speed_cap
		
		drone.global_position = global_position
		drone.set_meta("velocity", Vector2.ZERO) 
		
		drone_container.add_child(drone)
		_drones.append(drone)
		_drone_targets[drone] = null # Adiciona o drone ao dicionário, sem alvo

	# ... (geração de vigas continua igual) ...
	for i in range(drone_count):
		var beam = beam_scene.instantiate()
		beam.damage_amount = self.damage_amount
		beam.knockback_strength = self.knockback_strength
		beam_container.add_child(beam)
		_beams.append(beam)


# --- FUNÇÃO _find_targets TOTALMENTE REFEITA ---
func _find_targets() -> void:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	var assigned_enemies = [] # Lista de inimigos que JÁ estão sendo alvejados
	var free_drones = []      # Lista de drones que PRECISAM de um alvo
	
	# --- FASE 1: Validar alvos existentes ---
	# (Verifica se os drones ainda devem seguir seus alvos atuais)
	for drone in _drones:
		var current_target = _drone_targets.get(drone)
		
		var target_is_valid = false
		if is_instance_valid(current_target):
			# O alvo ainda está vivo E dentro do alcance?
			if global_position.distance_to(current_target.global_position) <= max_chase_radius:
				target_is_valid = true
		
		if target_is_valid:
			assigned_enemies.append(current_target) # O alvo é bom, mantém
		else:
			_drone_targets[drone] = null # Alvo perdido, libera o drone
			free_drones.append(drone)

	# Se todos os drones estão ocupados, não faz mais nada
	if free_drones.is_empty():
		return

	# --- FASE 2: Preparar lista de inimigos disponíveis ---
	var available_enemies = []
	for enemy in all_enemies:
		# Se o inimigo NÃO está na lista de 'assigned_enemies'
		# E ESTÁ dentro do alcance...
		if (not enemy in assigned_enemies) and (global_position.distance_to(enemy.global_position) <= max_chase_radius):
			available_enemies.append(enemy)
	
	# Se não há inimigos novos para pegar
	if available_enemies.is_empty():
		return

	# --- FASE 3: Drones livres escolhem alvos para maximizar a área ---
	for drone in free_drones:
		# Se acabaram os inimigos disponíveis
		if available_enemies.is_empty():
			break

		var best_target: Node2D = null
		
		if assigned_enemies.is_empty():
			# --- Lógica 1: O PRIMEIRO drone ancora ---
			# Pega o inimigo (disponível) mais próximo do JOGADOR.
			var min_dist_sq = INF
			for enemy in available_enemies:
				var dist_sq = global_position.distance_squared_to(enemy.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					best_target = enemy
		
		else:
			# --- Lógica 2: Drones SEGUINTES maximizam a área ---
			# Pega o inimigo (disponível) mais LONGE do centro dos alvos JÁ designados.
			
			# Calcula o "centro" de todos os alvos que já estão sendo mirados
			var centroid = _calculate_centroid(assigned_enemies)
			
			var max_dist_sq = -INF
			for enemy in available_enemies:
				var dist_sq = centroid.distance_squared_to(enemy.global_position)
				if dist_sq > max_dist_sq:
					max_dist_sq = dist_sq
					best_target = enemy

		# --- Atribui o alvo encontrado ---
		if best_target:
			_drone_targets[drone] = best_target      # Trava o alvo no drone
			assigned_enemies.append(best_target)   # Adiciona na lista de "ocupados"
			available_enemies.erase(best_target)   # Remove da lista de "disponíveis"

func _calculate_centroid(nodes: Array) -> Vector2:
	if nodes.is_empty():
		return global_position # Padrão é a posição do jogador
	
	var total_pos = Vector2.ZERO
	var valid_nodes = 0
	for node in nodes:
		if is_instance_valid(node):
			total_pos += node.global_position
			valid_nodes += 1
	
	if valid_nodes == 0:
		return global_position
		
	return total_pos / valid_nodes

# ... (O resto das funções, _on_activate, _on_attack_finished, regenerate_drones,
#      permanecem iguais) ...

func _on_activate(_params: Dictionary) -> void:
	for beam in _beams:
		beam.activate()

func _on_attack_finished() -> void:
	for beam in _beams:
		beam.deactivate()

func regenerate_drones():
	_generate_drones_and_beams()
