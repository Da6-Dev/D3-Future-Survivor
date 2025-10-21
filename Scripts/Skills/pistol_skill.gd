extends BaseAbility

@export_category("Pistol Parameters")
@export var bullet_scene: PackedScene
@export var projectile_count: int = 1
@export var knockback_strength: float = 100.0
@export var pierce_count: int = 0

var _target_enemy: CharacterBody2D = null

func _on_activate(_params: Dictionary) -> void:
	_find_closest_enemy()
	
	if is_instance_valid(_target_enemy):
		_shoot()

func _find_closest_enemy() -> void:
	_target_enemy = EntityManager.get_closest_enemy(global_position)

func _shoot() -> void:
	if not bullet_scene:
		return

	var base_direction = global_position.direction_to(_target_enemy.global_position)

	for i in range(projectile_count):
		var bullet_instance: Area2D = bullet_scene.instantiate()
		
		get_tree().root.add_child(bullet_instance)
		
		bullet_instance.player = player
		bullet_instance.global_position = global_position
		
		var angle_step_deg = 10.0
		var total_arc_deg = angle_step_deg * (projectile_count - 1)
		var start_angle_deg = -total_arc_deg / 2.0
		
		var spread_angle = deg_to_rad(start_angle_deg + i * angle_step_deg)
		var direction = base_direction.rotated(spread_angle)
		
		bullet_instance.set_direction(direction)
		
		bullet_instance.damage = self.damage_amount
		bullet_instance.knockback_strength = self.knockback_strength
		bullet_instance.pierce_count = self.pierce_count
