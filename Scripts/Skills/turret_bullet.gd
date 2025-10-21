extends BaseProjectile

var max_travel_distance: float = 500.0
var _distance_traveled: float = 0.0

func initialize_with_modifiers(mods: Dictionary):
	if mods.has("damage_amount"):
		damage += mods["damage_amount"]
	if mods.has("knockback_strength"):
		knockback_strength += mods["knockback_strength"]

func _physics_process(delta: float) -> void:
	var distance_to_move = speed * delta
	global_position += _direction * distance_to_move
	
	_distance_traveled += distance_to_move
	if _distance_traveled >= max_travel_distance:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var target = area.get_owner()
	
	if target.is_in_group("enemies"):
		_apply_damage(target)
		queue_free()
