extends Node2D

@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.2
@export var duration: float = 10.0
@export var attack_range: float = 400.0

@onready var visual: Node2D = $Visual
@onready var fire_timer: Timer = $FireTimer
@onready var duration_timer: Timer = $DurationTimer
@onready var muzzle: Marker2D = $Muzzle
var player: Node = null

var _target: Node2D = null
var _muzzle_default_pos_x: float = 0.0
var _total_fire_rate_multiplier: float = 1.0

var _bullet_modifiers: Dictionary = {}

func initialize_with_upgrades(upgrades: Array[AbilityUpgrade]):
	_total_fire_rate_multiplier = 1.0
	for upgrade in upgrades:
		if upgrade.modifiers.has("fire_rate_multiplier"):
			_total_fire_rate_multiplier += upgrade.modifiers["fire_rate_multiplier"]

	for upgrade in upgrades:
		for key in upgrade.modifiers:
			if key == "fire_rate_multiplier":
				continue 

			var modifier_value = upgrade.modifiers[key]
			
			if key in self:
				var current_value = get(key)
				set(key, current_value + modifier_value)
			else:
				_bullet_modifiers[key] = _bullet_modifiers.get(key, 0.0) + modifier_value

func _ready() -> void:
	if not bullet_scene:
		queue_free()
		return

	var final_wait_time = max(0.01, fire_rate / _total_fire_rate_multiplier)
	fire_timer.wait_time = final_wait_time
	
	duration_timer.wait_time = max(0.1, duration)
	
	fire_timer.timeout.connect(_shoot)
	fire_timer.start()
	
	duration_timer.one_shot = true
	duration_timer.timeout.connect(queue_free)
	duration_timer.start()
	
	_muzzle_default_pos_x = muzzle.position.x

func _process(delta: float) -> void:
	_find_target()
	_aim_at_target(delta)

func _find_target() -> void:
	if is_instance_valid(_target) and global_position.distance_to(_target.global_position) <= attack_range:
		return
	_target = EntityManager.get_closest_enemy(global_position, attack_range)

func _aim_at_target(delta: float):
	var target_direction_x = 0.0
	if is_instance_valid(_target):
		target_direction_x = _target.global_position.x - global_position.x
	
	var should_flip = false
	if abs(target_direction_x) > 1.0:
		should_flip = (target_direction_x < 0)
	
	if visual is Sprite2D or visual is AnimatedSprite2D:
		visual.flip_h = should_flip
	elif "scale" in visual:
		var target_scale_x = -1.0 if should_flip else 1.0
		visual.scale.x = lerp(visual.scale.x, target_scale_x, delta * 15.0)
	
	var target_muzzle_pos_x = -_muzzle_default_pos_x if should_flip else _muzzle_default_pos_x
	muzzle.position.x = lerp(muzzle.position.x, target_muzzle_pos_x, delta * 15.0)

func _shoot() -> void:
	if not is_instance_valid(_target):
		return

	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.player = player
	bullet.global_position = muzzle.global_position
	
	var shoot_direction = muzzle.global_position.direction_to(_target.global_position)
	bullet.set_direction(shoot_direction)
	
	if bullet.has_method("initialize_with_modifiers"):
		bullet.initialize_with_modifiers(_bullet_modifiers)
