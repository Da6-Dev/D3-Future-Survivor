extends BaseAbility

@export_category("Sword Skill Parameters")
@export var knockback_strength: float = 500.0

@onready var visual_area: Polygon2D = $SwordArea/AttackAreaVisual
@onready var collision_shape_2d: CollisionPolygon2D = $SwordArea/AttackAreaCollision
@onready var attack_area: Area2D = $SwordArea

func _ability_ready() -> void:
	visual_area.visible = false
	collision_shape_2d.disabled = true

	attack_area.area_entered.connect(_on_area_entered)
	on_deactivated.connect(_on_attack_finished)

func _on_activate(params: Dictionary) -> void:
	var attack_angle = params.get("attack_angle", 0.0)
	self.rotation = attack_angle

	visual_area.visible = true
	collision_shape_2d.disabled = false

func _on_attack_finished() -> void:
	visual_area.visible = false
	collision_shape_2d.disabled = true

func _on_area_entered(area: Area2D) -> void:
	var target = area.get_owner()

	if not is_instance_valid(player):
		return

	if target.has_method("take_damage"):
		var knockback_direction = (target.global_position - global_position).normalized()

		var final_damage = player.get_calculated_damage(damage_amount)
		target.take_damage(final_damage, knockback_direction, knockback_strength)
