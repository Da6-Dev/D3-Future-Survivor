class_name BaseAbility
extends Node2D

signal on_cooldown_started
signal on_cooldown_finished
signal on_deactivated

@export var icon: Texture2D
@export var ability_id: StringName
@export var cooldown_time: float = 1.0
@export var active_duration: float = 0.0
@export var damage_amount: float = 1.0
@export var requires_aiming: bool = false
@export var aim_at_closest_enemy: bool = true

var cooldown_modifier: float = 1.0
var total_attack_speed_multiplier: float = 1.0
var _cooldown_timer: Timer
var _active_duration_timer: Timer
var _is_unavailable: bool = false
var player: Node = null

func _init() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	_active_duration_timer = Timer.new()
	_active_duration_timer.one_shot = true
	_active_duration_timer.timeout.connect(_on_active_duration_finished)
	add_child(_active_duration_timer)

func _ready() -> void:
	_ability_ready()

func _ability_ready() -> void:
	pass

func _on_activate(_params: Dictionary) -> void:
	pass

func activate(params: Dictionary = {}) -> void:
	if _is_unavailable:
		return

	_is_unavailable = true
	_on_activate(params)

	if active_duration > 0:
		_active_duration_timer.wait_time = active_duration
		_active_duration_timer.start()
	else:
		call_deferred("_on_active_duration_finished")

func is_active() -> bool:
	if not is_instance_valid(_active_duration_timer):
		return false
	return not _active_duration_timer.is_stopped()

func _on_active_duration_finished():
	on_deactivated.emit()
	
	if not is_instance_valid(_cooldown_timer):
		_is_unavailable = false
		on_cooldown_finished.emit()
		return

	var final_cooldown = max(0.01, cooldown_time / total_attack_speed_multiplier) * cooldown_modifier
	if final_cooldown > 0:
		_cooldown_timer.wait_time = final_cooldown
		_cooldown_timer.start()
		on_cooldown_started.emit()
	else:
		_on_cooldown_timeout()

func _on_cooldown_timeout() -> void:
	_is_unavailable = false
	on_cooldown_finished.emit()

func is_on_cooldown() -> bool:
	if not is_instance_valid(_cooldown_timer):
		return false
	return not _cooldown_timer.is_stopped()

func get_time_left() -> float:
	if is_instance_valid(_active_duration_timer) and not _active_duration_timer.is_stopped():
		return _active_duration_timer.time_left
	if is_instance_valid(_cooldown_timer) and not _cooldown_timer.is_stopped():
		return _cooldown_timer.time_left
	return 0.0

func set_player_reference(p_player: Node) -> void:
	player = p_player
