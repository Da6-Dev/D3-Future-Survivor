extends Node2D

signal enemy_spawned(enemy_node: CharacterBody2D)

@export_group("Spawn Settings")
@export var enemy_scene: PackedScene
@export var spawn_interval_base: float = 3.0
@export var spawn_interval_variance: float = 0.8
@export var spawn_radius: float = 700.0
@export var max_enemies_on_screen: int = 20
@export var spawn_amount_per_wave: int = 1

@export_group("Miniboss Settings")
@export var miniboss_chance: float = 0.05
@export var miniboss_health_multiplier: float = 5.0
@export var miniboss_scale_multiplier: float = 1.5
@export var miniboss_xp_multiplier: float = 8.0

@onready var spawn_timer: Timer = $SpawnTimer
@onready var event_timer: Timer = $DifficultyTimer
@onready var hud: CanvasLayer = get_tree().get_first_node_in_group("hud_elements")
@onready var endless_timer: Timer = $EndlessTimer

var player: CharacterBody2D = null
var current_active_enemies: int = 0

var spawn_timeline: Array[Dictionary] = [
	# --- FASE 1: Aquecimento (0s - 90s) ---
	{"time": 5, "type": "set_interval", "params": {"interval": 2.5, "amount": 1}},
	{"time": 30, "type": "warning", "params": {"text": "Rajada Iminente!"}},
	{"time": 33, "type": "burst", "params": {"amount": 8, "radius_variance": 50}},
	{"time": 40, "type": "set_interval", "params": {"interval": 2.0, "amount": 1}},
	{"time": 60, "type": "warning", "params": {"text": "Emboscada!"}},
	{"time": 62, "type": "circle", "params": {"amount": 10, "radius": 400}},
	{"time": 80, "type": "set_interval", "params": {"interval": 1.8, "amount": 2}},

	# --- FASE 2: Aumento da Intensidade (90s - 180s) ---
	{"time": 90, "type": "warning", "params": {"text": "MINIBOSS!"}},
	{"time": 92, "type": "spawn_miniboss", "params": {}},
	{"time": 100, "type": "set_interval", "params": {"interval": 1.5, "amount": 2}},
	{"time": 120, "type": "set_miniboss_chance", "params": {"chance": 0.10}},
	{"time": 150, "type": "burst", "params": {"amount": 15, "radius_variance": 100}},
	{"time": 170, "type": "set_interval", "params": {"interval": 1.2, "amount": 3}},
	{"time": 175, "type": "set_max_enemies", "params": {"max": 30}},

	# --- FASE 3: Meio do Jogo (180s - 300s) ---
	{"time": 180, "type": "warning", "params": {"text": "Calmaria..."}},
	{"time": 181, "type": "lull", "params": {"duration": 8}},
	{"time": 190, "type": "warning", "params": {"text": "A Horda se Aproxima!"}},
	{"time": 192, "type": "circle", "params": {"amount": 20, "radius": 500}},
	{"time": 195, "type": "set_interval", "params": {"interval": 1.0, "amount": 3}},
	{"time": 240, "type": "warning", "params": {"text": "MINIBOSS DUPLO!"}},
	{"time": 242, "type": "spawn_miniboss", "params": {}},
	{"time": 243, "type": "spawn_miniboss", "params": {}},
	{"time": 250, "type": "set_interval", "params": {"interval": 0.8, "amount": 4}},
	{"time": 280, "type": "set_miniboss_chance", "params": {"chance": 0.15}},
	{"time": 290, "type": "set_max_enemies", "params": {"max": 40}},

	# --- FASE 4: Desafio (300s - 480s) ---
	{"time": 300, "type": "warning", "params": {"text": "Enxame!"}},
	{"time": 302, "type": "burst", "params": {"amount": 30, "radius_variance": 150}},
	{"time": 310, "type": "set_interval", "params": {"interval": 0.7, "amount": 4}},
	{"time": 360, "type": "warning", "params": {"text": "Cerco Total!"}},
	{"time": 362, "type": "circle", "params": {"amount": 30, "radius": 450}},
	{"time": 370, "type": "set_interval", "params": {"interval": 0.6, "amount": 5}},
	{"time": 420, "type": "lull", "params": {"duration": 5}},
	{"time": 426, "type": "warning", "params": {"text": "REFORÇOS DE ELITE!"}},
	{"time": 428, "type": "spawn_miniboss", "params": {}},
	{"time": 429, "type": "spawn_miniboss", "params": {}},
	{"time": 430, "type": "spawn_miniboss", "params": {}},
	{"time": 440, "type": "set_interval", "params": {"interval": 0.5, "amount": 5}},
	{"time": 460, "type": "set_miniboss_chance", "params": {"chance": 0.20}},
	{"time": 470, "type": "set_max_enemies", "params": {"max": 50}},

	# --- FASE 5: Clímax (480s - 600s) ---
	{"time": 480, "type": "warning", "params": {"text": "SOBREVIVA!"}},
	{"time": 482, "type": "burst", "params": {"amount": 40, "radius_variance": 50}},
	{"time": 490, "type": "set_interval", "params": {"interval": 0.4, "amount": 6}},
	{"time": 540, "type": "warning", "params": {"text": "CAOS!"}},
	{"time": 542, "type": "circle", "params": {"amount": 25, "radius": 600}},
	{"time": 543, "type": "burst", "params": {"amount": 25, "radius_variance": 100}},
	{"time": 550, "type": "set_interval", "params": {"interval": 0.3, "amount": 7}},
	{"time": 580, "type": "spawn_miniboss", "params": {}},
	{"time": 590, "type": "spawn_miniboss", "params": {}},

	# --- FASE 6: Infinito (600s+) ---
	{"time": 600, "type": "warning", "params": {"text": "SEM FIM!"}},
	{"time": 601, "type": "set_interval", "params": {"interval": 0.2, "amount": 8}},
	{"time": 602, "type": "set_miniboss_chance", "params": {"chance": 0.25}},
	{"time": 603, "type": "set_max_enemies", "params": {"max": 60}}
]

var _current_timeline_index: int = 0
var _game_time: float = 0
var _is_endless_mode: bool = false

func _ready():
	spawn_timer.wait_time = spawn_interval_base
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

	event_timer.wait_time = 1.0
	event_timer.timeout.connect(_on_event_timer_timeout)
	event_timer.start()

func _check_and_get_player() -> bool:
	if not is_instance_valid(player):
		player = EntityManager.get_player()
	return is_instance_valid(player)

func _on_event_timer_timeout():
	_game_time += event_timer.wait_time

	while _current_timeline_index < spawn_timeline.size() and \
		  _game_time >= spawn_timeline[_current_timeline_index]["time"]:
			
		var event = spawn_timeline[_current_timeline_index]
		_execute_spawn_event(event)
		if event.get("time", 0.0) >= 600 and not _is_endless_mode:
			_is_endless_mode = true
			endless_timer.start()
		_current_timeline_index += 1

func _execute_spawn_event(event: Dictionary):
	var type = event.get("type", "")
	var params = event.get("params", {})
	
	match type:
		"set_interval":
			spawn_interval_base = params.get("interval", spawn_interval_base)
			spawn_amount_per_wave = params.get("amount", spawn_amount_per_wave)
			_on_spawn_timer_timeout()
		"burst":
			_spawn_burst(params.get("amount", 5), params.get("radius_variance", 50.0))
		"circle":
			_spawn_circle(params.get("amount", 8), params.get("radius", 400.0))
		"lull":
			spawn_timer.stop()
			get_tree().create_timer(params.get("duration", 5.0), false).timeout.connect(spawn_timer.start)
		"warning":
			if hud and hud.has_method("show_warning"):
				hud.show_warning(params.get("text", "Atenção!"))
		"spawn_miniboss":
			_spawn_enemy(true)
		"set_miniboss_chance":
			miniboss_chance = params.get("chance", miniboss_chance)
		"set_max_enemies":
			max_enemies_on_screen = params.get("max", max_enemies_on_screen)
		_:
			pass
			
func _on_spawn_timer_timeout():
	var new_wait_time = spawn_interval_base + randf_range(-spawn_interval_variance, spawn_interval_variance)
	
	if spawn_amount_per_wave > 0 and spawn_interval_base > 0:
		spawn_timer.wait_time = max(0.05, new_wait_time)
		spawn_timer.start()
	else:
		spawn_timer.stop()

	if not _check_and_get_player():
		return
	
	if not enemy_scene:
		return
	if current_active_enemies >= max_enemies_on_screen:
		return
		
	for i in range(spawn_amount_per_wave):
		if current_active_enemies < max_enemies_on_screen:
			_spawn_enemy()
		else:
			break

func _spawn_enemy(force_miniboss: bool = false):
	if not _check_and_get_player():
		return
	if not enemy_scene: 
		return
	
	var random_angle = randf_range(0, TAU)
	var current_radius = spawn_radius + randf_range(-50.0, 50.0) 
	var spawn_direction = Vector2.RIGHT.rotated(random_angle)
	var spawn_position = player.global_position + spawn_direction * current_radius

	var enemy_instance = enemy_scene.instantiate() as CharacterBody2D
	if not enemy_instance: return

	var is_miniboss = force_miniboss or (randf() < miniboss_chance)
	
	if enemy_instance.has_method("setup_enemy"):
		if is_miniboss:
			enemy_instance.setup_enemy(true, miniboss_health_multiplier, miniboss_scale_multiplier, miniboss_xp_multiplier)
		else:
			enemy_instance.setup_enemy()

	enemy_instance.global_position = spawn_position
	var parent_node = get_parent()
	if parent_node is Node:
		parent_node.add_child(enemy_instance)
	else:
		enemy_instance.queue_free()
		return

	if enemy_instance.has_signal("died"):
		enemy_instance.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)

	current_active_enemies += 1
	emit_signal("enemy_spawned", enemy_instance)

func _spawn_burst(amount: int, radius_variance: float):
	if not _check_and_get_player():
		return
	if not enemy_scene: 
		return
	
	for i in range(amount):
		if current_active_enemies < max_enemies_on_screen:
			var random_angle = randf_range(0, TAU)
			var burst_radius = spawn_radius + randf_range(-radius_variance, radius_variance)
			var spawn_direction = Vector2.RIGHT.rotated(random_angle)
			var spawn_position = player.global_position + spawn_direction * burst_radius
			
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
			break

func _spawn_circle(amount: int, radius: float):
	if not _check_and_get_player():
		return
	if not enemy_scene: 
		return
	
	var angle_step = TAU / amount
	for i in range(amount):
		if current_active_enemies < max_enemies_on_screen:
			var angle = i * angle_step
			var spawn_direction = Vector2.RIGHT.rotated(angle)
			var spawn_position = player.global_position + spawn_direction * radius
			
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
			break

func _on_enemy_died(_enemy_node: CharacterBody2D):
	current_active_enemies -= 1
	current_active_enemies = maxi(0, current_active_enemies)

func set_player_reference(p_player: Node):
	player = p_player

func _on_endless_timer_timeout():
	spawn_interval_base = max(0.1, spawn_interval_base * 0.95)
	spawn_amount_per_wave += 1
	miniboss_chance = min(0.5, miniboss_chance + 0.01)
	miniboss_health_multiplier += 0.2
	max_enemies_on_screen += 5
	if spawn_timer.is_stopped() and spawn_amount_per_wave > 0:
		_on_spawn_timer_timeout()
