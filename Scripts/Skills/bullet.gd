extends BaseProjectile

func _on_area_entered(area: Area2D) -> void:
	var target = area.get_owner()
	
	if target.is_in_group("enemies") and not target in pierced_enemies:
		_apply_damage(target)
		pierced_enemies.append(target)
		_handle_pierce()
