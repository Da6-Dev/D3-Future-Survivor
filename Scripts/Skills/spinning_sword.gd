extends Area2D

signal sword_hit(target: Node, sword_node: Area2D)

func _on_area_entered(area: Area2D):
	var target = area.get_owner()
	emit_signal("sword_hit", target, self)
