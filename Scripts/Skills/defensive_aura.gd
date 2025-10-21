extends BaseAbility

@export_category("Defensive Aura Parameters")
@export var base_damage_interval: float = 1.0
@export var radius: float = 90.0
@export var knockback_strength: float = 300.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var aura_visual: Polygon2D = $AuraVisual

var _damage_timer: Timer
var _targets_in_aura: Array[CharacterBody2D] = []

func _ability_ready() -> void:
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape
	
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	aura_visual.polygon = points
	aura_visual.color = Color(0.5, 0.8, 1.0, 0.3)

	_damage_timer = Timer.new()
	_damage_timer.wait_time = max(0.05, base_damage_interval / total_attack_speed_multiplier)
	_damage_timer.autostart = true
	_damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(_damage_timer)

	var area = self
	if area is Area2D:
		area.area_entered.connect(_on_area_entered)
		area.area_exited.connect(_on_area_exited)

func _on_activate(_params: Dictionary) -> void:
	pass

func _on_damage_timer_timeout():
	for target in _targets_in_aura:
		if is_instance_valid(target) and target.has_method("take_damage"):
			var knockback_dir = (target.global_position - global_position).normalized()
			var final_damage = player.get_calculated_damage(damage_amount)
			target.take_damage(final_damage, knockback_dir, knockback_strength)

func _on_area_entered(area: Area2D):
	var target = area.get_owner()
	
	if target.is_in_group("enemies") and not _targets_in_aura.has(target):
		_targets_in_aura.append(target)

func _on_area_exited(area: Area2D):
	var target = area.get_owner()
	
	if _targets_in_aura.has(target):
		_targets_in_aura.erase(target)

func update_radius():
	var circle_shape = collision_shape.shape as CircleShape2D
	if circle_shape:
		circle_shape.radius = radius
	
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	aura_visual.polygon = points

func update_timers():
	if is_instance_valid(_damage_timer):
		_damage_timer.wait_time = max(0.05, base_damage_interval / total_attack_speed_multiplier)
