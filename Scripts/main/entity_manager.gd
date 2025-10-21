extends Node

# Listas que o jogo todo pode acessar
var active_enemies: Array[Node2D] = []
var player: Node2D = null
var camera_shaker: Node = null

# Funções para os inimigos se registrarem
func register_enemy(enemy: Node2D) -> void:
	if not enemy in active_enemies:
		active_enemies.append(enemy)

func unregister_enemy(enemy: Node2D) -> void:
	if enemy in active_enemies:
		active_enemies.erase(enemy)

# Funções para o jogador se registrar
func register_player(p_player: Node2D) -> void:
	player = p_player
	if is_instance_valid(player) and player.has_node("PlayerCamera/CameraShaker"):
		camera_shaker = player.get_node("PlayerCamera/CameraShaker")
	else:
		camera_shaker = null

func unregister_player() -> void:
	player = null
	camera_shaker = null

# --- AS NOVAS FUNÇÕES DE BUSCA ---

func get_player() -> Node2D:
	return player

func get_active_enemies() -> Array[Node2D]:
	return active_enemies

# A função centralizada que substitui 90% da sua lógica
func get_closest_enemy(position: Vector2, max_range: float = INF) -> Node2D:
	var closest_enemy: Node2D = null
	var min_dist_sq = INF
	
	# Itera na nossa lista PRONTA, em vez de varrer a árvore
	for enemy in active_enemies:
		# Verifica se o inimigo ainda é válido (pode ter morrido e não ter saído da lista)
		if not is_instance_valid(enemy):
			continue
			
		var dist_sq = position.distance_squared_to(enemy.global_position)
		
		# Verifica se é o mais próximo E está dentro do alcance
		if dist_sq < min_dist_sq and dist_sq <= max_range * max_range:
			min_dist_sq = dist_sq
			closest_enemy = enemy
			
	return closest_enemy

func trigger_shake(strength: float, duration: float, frequency: float) -> void:
	if is_instance_valid(camera_shaker) and camera_shaker.has_method("shake"):
		camera_shaker.shake(strength, duration, frequency)
