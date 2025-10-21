extends BaseProjectile

var stun_duration: float = 1.0

func _on_area_entered(area: Area2D) -> void:
	var target = area.get_owner()
	
	if target.is_in_group("enemies") and not target in pierced_enemies:
		_apply_damage(target)
		if target.has_method("apply_stun"):
			target.apply_stun(stun_duration)
		pierced_enemies.append(target)
		_handle_pierce()
