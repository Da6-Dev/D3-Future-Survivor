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

var player: CharacterBody2D = null
var current_active_enemies: int = 0

var spawn_timeline: Array[Dictionary] = [
	{"time": 5, "type": "set_interval", "params": {"interval": 2.5, "amount": 1}},
	{"time": 30, "type": "warning", "params": {"text": "Rajada Iminente!"}},
	{"time": 33, "type": "burst", "params": {"amount": 8, "radius_variance": 50}},
	{"time": 40, "type": "set_interval", "params": {"interval": 2.0, "amount": 1}},
	{"time": 60, "type": "warning", "params": {"text": "Emboscada!"}},
	{"time": 62, "type": "circle", "params": {"amount": 10, "radius": 400}},
	{"time": 70, "type": "set_interval", "params": {"interval": 5.0, "amount": 0}},
	{"time": 70, "type": "lull", "params": {"duration": 8}},
	{"time": 80, "type": "warning", "params": {"text": "MINIBOSS!"}},
	{"time": 82, "type": "spawn_miniboss", "params": {}},
	{"time": 90, "type": "set_interval", "params": {"interval": 1.5, "amount": 2}},
	{"time": 90, "type": "set_miniboss_chance", "params": {"chance": 0.10}},
]
var _current_timeline_index: int = 0
var _game_time: float = 0.0

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
