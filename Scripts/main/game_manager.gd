extends Node

const AbilityUpgradeScript = preload("res://Scripts/Resources/AbilityUpgrade.gd")

var upgrade_screen: CanvasLayer 
var player: CharacterBody2D

var available_upgrades: Array[AbilityUpgrade] = []
var is_game_paused: bool = false
var _is_upgrade_signal_connected: bool = false

func _ready() -> void:
	_load_upgrades_from_disk()

func pause_game():
	is_game_paused = true
	get_tree().paused = true

func unpause_game():
	is_game_paused = false
	get_tree().paused = false
	
func begin_level_up():
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	if not is_instance_valid(upgrade_screen):
		upgrade_screen = get_tree().get_first_node_in_group("upgrade_screen_group")
		if not upgrade_screen:
			return
	
	if not _is_upgrade_signal_connected:
		upgrade_screen.upgrade_selected.connect(on_upgrade_chosen)
		_is_upgrade_signal_connected = true

	pause_game()
	
	var upgrade_pool: Array[AbilityUpgrade] = []
	var player_abilities: Array[StringName] = player.active_abilities.keys()
	
	var ability_upgrade_weight = 3
	var new_ability_weight = 5
	var passive_upgrade_weight = 1

	for upgrade in available_upgrades:
		
		if upgrade.type == AbilityUpgrade.UpgradeType.UPGRADE_EXISTING_ABILITY:
			if upgrade.target_ability_id in player_abilities:
				for i in range(ability_upgrade_weight):
					upgrade_pool.append(upgrade)
					
		elif upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY:
			if player.has_empty_ability_slot() and not upgrade.target_ability_id in player_abilities:
				for i in range(new_ability_weight):
					upgrade_pool.append(upgrade)
					
		elif upgrade.type == AbilityUpgrade.UpgradeType.APPLY_PASSIVE_STAT:
			var stat_id = upgrade.passive_stat_id
			if (not player.active_passives.has(stat_id) and player.has_empty_passive_slot()) or \
			   player.active_passives.has(stat_id):
				for i in range(passive_upgrade_weight):
					upgrade_pool.append(upgrade)

	var chosen_upgrades: Array[AbilityUpgrade] = []
	upgrade_pool.shuffle()
	
	for upgrade in upgrade_pool:
		if not upgrade in chosen_upgrades:
			chosen_upgrades.append(upgrade)
		if chosen_upgrades.size() >= 3:
			break
	
	upgrade_screen.show_options(chosen_upgrades)

func on_upgrade_chosen(chosen_upgrade: AbilityUpgrade):
	if is_instance_valid(player):
		player.apply_upgrade(chosen_upgrade)
	unpause_game()

func _load_upgrades_from_disk() -> void:
	available_upgrades.clear()
	
	ResourceLoaderUtils.populate_resources_from_path(
		available_upgrades,
		"res://Upgrades",
		AbilityUpgradeScript,
		true
	)
