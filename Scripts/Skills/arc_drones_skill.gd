extends BaseAbility

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

var _drone_targets: Dictionary = {}

func _ability_ready() -> void:
	if not beam_scene or not drone_scene:
		return

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
	if _drones.size() != drone_count:
		regenerate_drones()
	if _drones.size() != drone_count:
		return 
			
	_time += delta
	pivot.rotation += rotation_speed * delta
	
	var home_angle_step = TAU / drone_count
	
	for i in range(_drones.size()):
		var drone = _drones[i] 
		var velocity: Vector2 = drone.get_meta("velocity", Vector2.ZERO)

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
	
	if _beams.size() != drone_count:
		return 
		
	for i in range(_beams.size()):
		var beam = _beams[i]
		
		if i < _drones.size():
			var drone_a = _drones[i]
			var next_drone_index = (i + 1) % _drones.size()
			if next_drone_index < _drones.size():
				var drone_b = _drones[next_drone_index]
				beam.update_beam(drone_a.global_position, drone_b.global_position)

func _generate_drones_and_beams() -> void:
	for child in drone_container.get_children(): child.queue_free()
	for child in beam_container.get_children(): child.queue_free()
	_drones.clear()
	_beams.clear()
	_drone_targets.clear()

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
		_drone_targets[drone] = null

	for i in range(drone_count):
		var beam = beam_scene.instantiate()
		beam.damage_amount = self.damage_amount
		beam.knockback_strength = self.knockback_strength
		beam_container.add_child(beam)
		_beams.append(beam)

func _find_targets() -> void:
	var all_enemies = EntityManager.get_active_enemies()
	
	var assigned_enemies = []
	var free_drones = []
	
	for drone in _drones:
		var current_target = _drone_targets.get(drone)
		
		var target_is_valid = false
		if is_instance_valid(current_target):
			if global_position.distance_to(current_target.global_position) <= max_chase_radius:
				target_is_valid = true
		
		if target_is_valid:
			assigned_enemies.append(current_target)
		else:
			_drone_targets[drone] = null
			free_drones.append(drone)

	if free_drones.is_empty():
		return

	var available_enemies = []
	for enemy in all_enemies:
		if (not enemy in assigned_enemies) and (global_position.distance_to(enemy.global_position) <= max_chase_radius):
			available_enemies.append(enemy)
	
	if available_enemies.is_empty():
		return

	for drone in free_drones:
		if available_enemies.is_empty():
			break

		var best_target: Node2D = null
		
		if assigned_enemies.is_empty():
			var min_dist_sq = INF
			for enemy in available_enemies:
				var dist_sq = global_position.distance_squared_to(enemy.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					best_target = enemy
		
		else:
			var centroid = _calculate_centroid(assigned_enemies)
			
			var max_dist_sq = -INF
			for enemy in available_enemies:
				var dist_sq = centroid.distance_squared_to(enemy.global_position)
				if dist_sq > max_dist_sq:
					max_dist_sq = dist_sq
					best_target = enemy

		if best_target:
			_drone_targets[drone] = best_target
			assigned_enemies.append(best_target)
			available_enemies.erase(best_target)

func _calculate_centroid(nodes: Array) -> Vector2:
	if nodes.is_empty():
		return global_position
	
	var total_pos = Vector2.ZERO
	var valid_nodes = 0
	for node in nodes:
		if is_instance_valid(node):
			total_pos += node.global_position
			valid_nodes += 1
	
	if valid_nodes == 0:
		return global_position
		
	return total_pos / valid_nodes

func _on_activate(_params: Dictionary) -> void:
	for beam in _beams:
		beam.activate()

func _on_attack_finished() -> void:
	for beam in _beams:
		beam.deactivate()

func regenerate_drones():
	_generate_drones_and_beams()
