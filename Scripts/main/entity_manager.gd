extends Node

var active_enemies: Array[Node2D] = []
var player: Node2D = null
var camera_shaker: Node = null
var pause_menu: CanvasLayer = null
var settings_menu: CanvasLayer = null
var game_over_screen: CanvasLayer = null

# --- FUNÇÃO ADICIONADA ---
# Esta função limpa todo o estado do EntityManager.
# É chamada pelo GameManager quando a cena é trocada.
func reset() -> void:
	active_enemies.clear()
	player = null
	camera_shaker = null
	pause_menu = null
	settings_menu = null
	game_over_screen = null

func register_enemy(enemy: Node2D) -> void:
	if not enemy in active_enemies:
		active_enemies.append(enemy)

func unregister_enemy(enemy: Node2D) -> void:
	if enemy in active_enemies:
		active_enemies.erase(enemy)

func register_player(p_player: Node2D) -> void:
	player = p_player
	if is_instance_valid(player) and player.has_node("PlayerCamera/CameraShaker"):
		camera_shaker = player.get_node("PlayerCamera/CameraShaker")
	else:
		camera_shaker = null

func unregister_player() -> void:
	# --- MODIFICADO ---
	# Em vez de limpar manualmente, apenas chamamos a função reset.
	reset()

func get_player() -> Node2D:
	return player

func get_active_enemies() -> Array[Node2D]:
	return active_enemies

func get_closest_enemy(position: Vector2, max_range: float = INF) -> Node2D:
	var closest_enemy: Node2D = null
	var min_dist_sq = INF

	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
			
		var dist_sq = position.distance_squared_to(enemy.global_position)
		
		if dist_sq < min_dist_sq and dist_sq <= max_range * max_range:
			min_dist_sq = dist_sq
			closest_enemy = enemy
			
	return closest_enemy

func trigger_shake(strength: float, duration: float, frequency: float) -> void:
	if is_instance_valid(camera_shaker) and camera_shaker.has_method("shake"):
		camera_shaker.shake(strength, duration, frequency)

func register_pause_menu(p_menu: CanvasLayer):
	pause_menu = p_menu

func register_settings_menu(s_menu: CanvasLayer):
	settings_menu = s_menu

func get_pause_menu() -> CanvasLayer:
	return pause_menu

func get_settings_menu() -> CanvasLayer:
	return settings_menu

func register_game_over_screen(go_screen: CanvasLayer):
	game_over_screen = go_screen

func get_game_over_screen() -> CanvasLayer:
	return game_over_screen
