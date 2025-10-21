# Scripts/Skills/turret_skill.gd
extends BaseAbility

@export var turret_scene: PackedScene
@export var placement_offset: float = 60.0

func _ready() -> void:
	if not turret_scene:
		push_error("Cena da Torreta (turret_scene) não definida na Habilidade!")
	
	ability_id = &"deploy_turret"
	cooldown_time = 8.0
	active_duration = 0.0

func _on_activate(_params: Dictionary) -> void:
	if not turret_scene:
		return

	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		push_warning("Jogador não encontrado para colocar a torreta!")
		return

	var placement_direction = -player.last_direction
	if placement_direction == Vector2.ZERO: placement_direction = Vector2.DOWN
	var placement_position = player.global_position + placement_direction * placement_offset

	var turret_instance = turret_scene.instantiate()
	turret_instance.player = player # Passa a referência do player

	# --- VALIDAÇÃO DOS UPGRADES AQUI ---
	if player.has_method("get_upgrades_for_ability"):
		# 1. Pega o array genérico retornado pela função
		var upgrades_generic: Array = player.get_upgrades_for_ability(ability_id)

		# 2. Cria um NOVO array que SÓ conterá AbilityUpgrades válidos
		var valid_upgrades: Array[AbilityUpgrade] = []
		for item in upgrades_generic:
			if item is AbilityUpgrade: # Verifica se o item é do tipo correto
				valid_upgrades.append(item) # Adiciona ao array validado
			else:
				push_warning("Item inválido encontrado na lista de upgrades para ", ability_id)

		# 3. Passa o array VALIDADO para a torreta
		if turret_instance.has_method("initialize_with_upgrades"):
			# Só chama se tivermos upgrades válidos para passar
			if not valid_upgrades.is_empty():
				turret_instance.initialize_with_upgrades(valid_upgrades)
		elif not valid_upgrades.is_empty():
			push_warning("Torreta instanciada não tem o método 'initialize_with_upgrades'!")
	# ------------------------------------

	get_tree().root.add_child(turret_instance)
	turret_instance.global_position = placement_position
