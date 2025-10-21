# Scripts/Skills/sword_skill.gd
extends BaseAbility

@export_category("Sword Skill Parameters")
@export var knockback_strength: float = 500.0

@onready var visual_area: Polygon2D = $SwordArea/AttackAreaVisual
@onready var collision_shape_2d: CollisionPolygon2D = $SwordArea/AttackAreaCollision
@onready var attack_area: Area2D = $SwordArea

func _ability_ready() -> void:
	visual_area.visible = false
	collision_shape_2d.disabled = true

	# --- CORREÇÃO AQUI ---
	# Trocamos o sinal de 'body_entered' para 'area_entered'
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

# --- CORREÇÃO AQUI ---
# A função foi renomeada para '_on_area_entered' e o parâmetro mudou para 'area: Area2D'
func _on_area_entered(area: Area2D) -> void:
	# O 'area' é o Hurtbox. 'area.get_owner()' é o Inimigo.
	var target = area.get_owner()
	
	if not is_active():
		return

	if target.has_method("take_damage"):
		var knockback_direction = (target.global_position - global_position).normalized()
		# Chamamos 'take_damage' diretamente no inimigo (target)
		var final_damage = player.get_calculated_damage(damage_amount)
		target.take_damage(final_damage, knockback_direction, knockback_strength)
