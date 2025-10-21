# Scripts/enemies/enemy_spawner.gd
extends Node2D

signal enemy_spawned(enemy_node: CharacterBody2D)

@export_group("Spawn Settings")
@export var enemy_scene: PackedScene
@export var spawn_interval_base: float = 3.0 # Aumentar um pouco o intervalo base normal
@export var spawn_interval_variance: float = 0.8
@export var spawn_radius: float = 700.0
@export var max_enemies_on_screen: int = 20 # Aumentar o limite para acomodar ondas
@export var spawn_amount_per_wave: int = 1 # Quantidade para spawn NORMAL

# --- PROGRESSÃO REMOVIDA DAQUI ---
# As variáveis min_spawn_interval, max_spawn_amount, etc.,
# serão controladas pela timeline agora.

@export_group("Miniboss Settings")
@export var miniboss_chance: float = 0.05
@export var miniboss_health_multiplier: float = 5.0
@export var miniboss_scale_multiplier: float = 1.5
@export var miniboss_xp_multiplier: float = 8.0

const PLAYER_GROUP_NAME: String = "player"

@onready var spawn_timer: Timer = $SpawnTimer # Timer para spawn normal
@onready var event_timer: Timer = $DifficultyTimer # Renomeado para clareza
@onready var hud: CanvasLayer = get_tree().get_first_node_in_group("hud_elements") # Assumindo que o HUD está em um grupo

var player: CharacterBody2D = null
var current_active_enemies: int = 0
# Removido current_xp_bonus, o XP virá dos inimigos/minibosses

# --- NOVA TIMELINE DE SPAWN ---
# Array de Dicionários. Cada dicionário é um evento.
# 'time': Segundos de jogo para disparar o evento.
# 'type': O tipo de evento (ex: "burst", "circle", "miniboss", "lull", "set_interval").
# 'params': Dicionário com parâmetros específicos do evento.
var spawn_timeline: Array[Dictionary] = [
	# Primeiros 30 segundos: Spawns normais lentos
	{"time": 5, "type": "set_interval", "params": {"interval": 2.5, "amount": 1}},
	# 30 Segundos: Primeira rajada
	{"time": 30, "type": "warning", "params": {"text": "Rajada Iminente!"}},
	{"time": 33, "type": "burst", "params": {"amount": 8, "radius_variance": 50}},
	# 40 Segundos: Volta ao normal, um pouco mais rápido
	{"time": 40, "type": "set_interval", "params": {"interval": 2.0, "amount": 1}},
	# 1 Minuto: Emboscada
	{"time": 60, "type": "warning", "params": {"text": "Emboscada!"}},
	{"time": 62, "type": "circle", "params": {"amount": 10, "radius": 400}},
	# 1:10 Minuto: Calmaria
	{"time": 70, "type": "set_interval", "params": {"interval": 5.0, "amount": 0}}, # Para o spawn normal
	{"time": 70, "type": "lull", "params": {"duration": 8}}, # Pausa antes do próximo
	# 1:20 Minuto: Primeiro Miniboss
	{"time": 80, "type": "warning", "params": {"text": "MINIBOSS!"}},
	{"time": 82, "type": "spawn_miniboss", "params": {}},
	# 1:30 Minuto: Normal mais rápido + chance maior de miniboss normal
	{"time": 90, "type": "set_interval", "params": {"interval": 1.5, "amount": 2}},
	{"time": 90, "type": "set_miniboss_chance", "params": {"chance": 0.10}}, # Aumenta a chance normal
	# Adicione mais eventos aqui...
]
var _current_timeline_index: int = 0
var _game_time: float = 0.0

func _ready():
	_find_player()
	if not is_instance_valid(player):
		get_tree().create_timer(1.0, false).timeout.connect(_find_player)

	# Configura o timer de spawn normal (começa com o valor base)
	spawn_timer.wait_time = spawn_interval_base
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

	# Configura o timer de eventos para rodar a cada segundo
	event_timer.wait_time = 1.0
	event_timer.timeout.connect(_on_event_timer_timeout)
	event_timer.start()

# ... (_find_player permanece igual) ...
func _find_player():
	var player_nodes = get_tree().get_nodes_in_group(PLAYER_GROUP_NAME)
	if player_nodes.size() > 0:
		player = player_nodes[0]
	else:
		player = null
		# printerr(...) # Pode remover o print se estiver funcionando
		

# Chamado a cada segundo pelo event_timer (antigo difficulty_timer)
func _on_event_timer_timeout():
	_game_time += event_timer.wait_time # Incrementa o tempo de jogo

	# Verifica se há eventos na timeline para disparar neste segundo
	while _current_timeline_index < spawn_timeline.size() and \
		  _game_time >= spawn_timeline[_current_timeline_index]["time"]:
		
		var event = spawn_timeline[_current_timeline_index]
		_execute_spawn_event(event)
		_current_timeline_index += 1

# Função que direciona para a lógica de cada tipo de evento
func _execute_spawn_event(event: Dictionary):
	var type = event.get("type", "")
	var params = event.get("params", {})
	
	print("Executando Evento: ", type, " em ", _game_time, "s | Params: ", params)

	match type:
		"set_interval":
			spawn_interval_base = params.get("interval", spawn_interval_base)
			spawn_amount_per_wave = params.get("amount", spawn_amount_per_wave)
			# Atualiza o timer de spawn normal imediatamente
			_on_spawn_timer_timeout() # Chama para reiniciar com novos valores
		"burst":
			_spawn_burst(params.get("amount", 5), params.get("radius_variance", 50.0))
		"circle":
			_spawn_circle(params.get("amount", 8), params.get("radius", 400.0))
		"lull":
			# Pausa o timer de spawn normal
			spawn_timer.stop()
			# Agenda o reinício do timer após a duração da calmaria
			get_tree().create_timer(params.get("duration", 5.0), false).timeout.connect(spawn_timer.start)
		"warning":
			# Mostra um aviso na tela (precisa implementar no HUD)
			if hud and hud.has_method("show_warning"):
				hud.show_warning(params.get("text", "Atenção!"))
			else:
				print("AVISO: ", params.get("text", "Atenção!"))
		"spawn_miniboss":
			# Spawna UM miniboss garantido
			_spawn_enemy(true) # Passa true para forçar miniboss
		"set_miniboss_chance":
			miniboss_chance = params.get("chance", miniboss_chance)
		_:
			push_warning("Tipo de evento de spawn desconhecido: ", type)
			
# (Em Scripts/enemies/enemy_spawner.gd)

# Spawn Normal (chamado pelo spawn_timer)
func _on_spawn_timer_timeout():
	# Reinicia o timer com variação
	var new_wait_time = spawn_interval_base + randf_range(-spawn_interval_variance, spawn_interval_variance)
	# Garante que amount > 0 antes de setar wait_time > 0
	if spawn_amount_per_wave > 0 and spawn_interval_base > 0:
		spawn_timer.wait_time = max(0.05, new_wait_time) # Mínimo um pouco maior
		spawn_timer.start()
	else:
		spawn_timer.stop() # Para o timer se amount ou interval for 0

	# Spawna a quantidade normal
	if not is_instance_valid(player) or not enemy_scene:
		return
	if current_active_enemies >= max_enemies_on_screen:
		return
		
	for i in range(spawn_amount_per_wave):
		if current_active_enemies < max_enemies_on_screen:
			_spawn_enemy() # Usa a lógica padrão (com chance de miniboss normal)
		else:
			break

# Função base _spawn_enemy (ligeiramente modificada para aceitar 'force_miniboss')
func _spawn_enemy(force_miniboss: bool = false): # Adicionado parâmetro
	if not is_instance_valid(player) or not enemy_scene: return # Segurança extra
	
	var random_angle = randf_range(0, TAU)
	# Adiciona variação ao raio base para rajadas
	var current_radius = spawn_radius + randf_range(-50.0, 50.0) 
	var spawn_direction = Vector2.RIGHT.rotated(random_angle)
	var spawn_position = player.global_position + spawn_direction * current_radius

	var enemy_instance = enemy_scene.instantiate() as CharacterBody2D
	if not enemy_instance: return

	# Lógica do Miniboss (usa 'force_miniboss' ou a chance normal)
	var is_miniboss = force_miniboss or (randf() < miniboss_chance)
	
	if enemy_instance.has_method("setup_enemy"):
		if is_miniboss:
			enemy_instance.setup_enemy(true, miniboss_health_multiplier, miniboss_scale_multiplier, miniboss_xp_multiplier)
			if force_miniboss: print("!!! Evento Miniboss Spawned !!!") # Log diferente
		else:
			enemy_instance.setup_enemy()
	else:
		push_warning("Inimigo instanciado não possui o método 'setup_enemy'.")

	# (XP Bônus removido daqui, pois foi removido do script)
	# enemy_instance.xp_amount += int(current_xp_bonus)

	enemy_instance.global_position = spawn_position
	# Adiciona ao NÓ PAI do spawner (geralmente o nó 'World')
	# Garante que get_parent() seja um Node antes de chamar add_child
	var parent_node = get_parent()
	if parent_node is Node:
		parent_node.add_child(enemy_instance)
	else:
		push_error("Spawner não tem um nó pai válido para adicionar inimigos!")
		enemy_instance.queue_free() # Libera a instância se não puder adicionar
		return

	if enemy_instance.has_signal("died"):
		enemy_instance.died.connect(_on_enemy_died, CONNECT_ONE_SHOT) # Conexão simplificada
	else:
		push_warning("Spawner: Inimigo instanciado não possui o sinal 'died'.")

	current_active_enemies += 1
	emit_signal("enemy_spawned", enemy_instance)

# Função para spawnar em Rajada (Burst)
func _spawn_burst(amount: int, radius_variance: float):
	if not is_instance_valid(player) or not enemy_scene: return
	
	print("--- Iniciando Burst Spawn: ", amount, " inimigos ---")
	for i in range(amount):
		if current_active_enemies < max_enemies_on_screen:
			var random_angle = randf_range(0, TAU)
			# Usa o spawn_radius base +/- a variação definida no evento
			var burst_radius = spawn_radius + randf_range(-radius_variance, radius_variance)
			var spawn_direction = Vector2.RIGHT.rotated(random_angle)
			var spawn_position = player.global_position + spawn_direction * burst_radius
			
			# Reutiliza a lógica de _spawn_enemy, mas define a posição manualmente
			var enemy_instance = enemy_scene.instantiate() as CharacterBody2D
			if not enemy_instance: continue

			var is_miniboss = (randf() < miniboss_chance) # Chance normal de miniboss na rajada
			if enemy_instance.has_method("setup_enemy"):
				enemy_instance.setup_enemy(is_miniboss, miniboss_health_multiplier if is_miniboss else 1.0, miniboss_scale_multiplier if is_miniboss else 1.0, miniboss_xp_multiplier if is_miniboss else 1.0)
			
			enemy_instance.global_position = spawn_position
			var parent_node = get_parent()
			if parent_node is Node: parent_node.add_child(enemy_instance)
			else: enemy_instance.queue_free(); continue
				
			if enemy_instance.has_signal("died"): enemy_instance.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
			current_active_enemies += 1
			emit_signal("enemy_spawned", enemy_instance)
		else:
			print("Limite de inimigos atingido durante Burst.")
			break # Para a rajada se o limite for atingido

# Função para spawnar em Círculo (Emboscada)
func _spawn_circle(amount: int, radius: float):
	if not is_instance_valid(player) or not enemy_scene: return
	
	print("--- Iniciando Circle Spawn (Emboscada): ", amount, " inimigos a raio ", radius, " ---")
	var angle_step = TAU / amount
	for i in range(amount):
		if current_active_enemies < max_enemies_on_screen:
			var angle = i * angle_step
			var spawn_direction = Vector2.RIGHT.rotated(angle)
			# Usa o raio definido no evento
			var spawn_position = player.global_position + spawn_direction * radius
			
			# Reutiliza a lógica (similar ao burst)
			var enemy_instance = enemy_scene.instantiate() as CharacterBody2D
			if not enemy_instance: continue

			var is_miniboss = (randf() < miniboss_chance)
			if enemy_instance.has_method("setup_enemy"):
				enemy_instance.setup_enemy(is_miniboss, miniboss_health_multiplier if is_miniboss else 1.0, miniboss_scale_multiplier if is_miniboss else 1.0, miniboss_xp_multiplier if is_miniboss else 1.0)

			enemy_instance.global_position = spawn_position
			var parent_node = get_parent()
			if parent_node is Node: parent_node.add_child(enemy_instance)
			else: enemy_instance.queue_free(); continue

			if enemy_instance.has_signal("died"): enemy_instance.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
			current_active_enemies += 1
			emit_signal("enemy_spawned", enemy_instance)
		else:
			print("Limite de inimigos atingido durante Circle.")
			break

# ... (_on_enemy_died permanece igual) ...
func _on_enemy_died(_enemy_node: CharacterBody2D):
	current_active_enemies -= 1
	current_active_enemies = maxi(0, current_active_enemies)
