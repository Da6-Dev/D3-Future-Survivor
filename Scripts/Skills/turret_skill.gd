extends BaseAbility

@export var turret_scene: PackedScene
@export var placement_offset: float = 60.0

func _ready() -> void:
	if not turret_scene:
		return
	
	ability_id = &"deploy_turret"
	cooldown_time = 8.0
	active_duration = 0.0

func _on_activate(_params: Dictionary) -> void:
	if not turret_scene:
		return

	player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	var placement_direction = -player.last_direction
	if placement_direction == Vector2.ZERO: placement_direction = Vector2.DOWN
	var placement_position = player.global_position + placement_direction * placement_offset

	var turret_instance = turret_scene.instantiate()
	turret_instance.player = player

	if player.has_method("get_upgrades_for_ability"):
		var upgrades_generic: Array = player.get_upgrades_for_ability(ability_id)

		var valid_upgrades: Array[AbilityUpgrade] = []
		for item in upgrades_generic:
			if item is AbilityUpgrade:
				valid_upgrades.append(item)

		if turret_instance.has_method("initialize_with_upgrades"):
			if not valid_upgrades.is_empty():
				turret_instance.initialize_with_upgrades(valid_upgrades)
	
	get_tree().root.add_child(turret_instance)
	turret_instance.global_position = placement_position
