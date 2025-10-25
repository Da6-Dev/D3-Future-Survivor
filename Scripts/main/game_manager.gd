extends Node

const AbilityUpgradeScript = preload("res://Scripts/Resources/AbilityUpgrade.gd")

var upgrade_screen: CanvasLayer
var player: CharacterBody2D

var available_upgrades: Array[AbilityUpgrade] = []
var is_game_paused: bool = false
var _is_upgrade_signal_connected: bool = false
var _pending_level_ups: int = 0

func _ready() -> void:
	set_process_unhandled_input(true)
	
	_load_upgrades_from_disk()
	get_tree().scene_changed.connect(_on_scene_changed)
	_find_and_connect_player()

func _find_and_connect_player():
	player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		if not player.game_over.is_connected(_on_player_game_over):
			player.game_over.connect(_on_player_game_over)

func pause_game():
	is_game_paused = true
	get_tree().paused = true

func unpause_game():
	is_game_paused = false
	get_tree().paused = false

func begin_level_up():
	if is_game_paused:
		_pending_level_ups += 1
		return
	
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
	
	if _pending_level_ups > 0:
		_pending_level_ups -= 1
		call_deferred("begin_level_up")

func _load_upgrades_from_disk() -> void:
	available_upgrades.clear()

	ResourceLoaderUtils.populate_resources_from_path(
		available_upgrades,
		"res://Upgrades",
		AbilityUpgradeScript,
		true
	)

func _connect_pause_signals():
	var pause_menu = EntityManager.get_pause_menu()
	var settings_menu = EntityManager.get_settings_menu()

	if is_instance_valid(pause_menu) and is_instance_valid(settings_menu):

		if not pause_menu.settings_pressed.is_connected(_on_settings_open):
			pause_menu.settings_pressed.connect(_on_settings_open)

		if not settings_menu.back_pressed.is_connected(_on_settings_close):
			settings_menu.back_pressed.connect(_on_settings_close)

func _unhandled_input(event: InputEvent):
	if event.is_action("ui_pause") and event.is_pressed() and not event.is_echo():
		
		var pause_menu = EntityManager.get_pause_menu()
		
		# Esta verificação agora deve funcionar, pois o menu teve tempo de se registrar.
		if not is_instance_valid(pause_menu):
			print("Pause failed: Pause menu instance is invalid.")
			return

		if not is_game_paused:
			if not is_instance_valid(upgrade_screen) or not upgrade_screen.visible:

				_connect_pause_signals()

				pause_game()
				if is_instance_valid(pause_menu):
					pause_menu.open_menu()
				get_viewport().set_input_as_handled()

func _on_settings_open():
	var settings_menu = EntityManager.get_settings_menu()
	if is_instance_valid(settings_menu):
		settings_menu.open_menu()

func _on_settings_close():
	var pause_menu = EntityManager.get_pause_menu()
	if is_instance_valid(pause_menu):
		pause_menu.open_menu()

func _on_player_game_over(time_survived: float, final_stats: PlayerStats,
						 final_upgrades: Dictionary, final_passives: Dictionary,
						 final_level: int, final_xp: float, final_xp_needed: float):
	pause_game()

	var go_screen = EntityManager.get_game_over_screen()
	if is_instance_valid(go_screen):
		go_screen.show_game_over(time_survived, final_stats, final_upgrades,
								 final_passives, final_level, final_xp, final_xp_needed)
	else:
		printerr("Tela de Game Over não encontrada!")
		unpause_game()
		get_tree().change_scene_to_file("res://Scenes/main/main_menu.tscn")

func _on_scene_changed():
	player = null
	upgrade_screen = null
	_is_upgrade_signal_connected = false
	_pending_level_ups = 0
	
	unpause_game()

	_find_and_connect_player()
