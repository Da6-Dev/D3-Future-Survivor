extends CanvasLayer

const UPGRADE_ICON_SCENE = preload("res://Scenes/ui/upgrade_display_icon.tscn")

@onready var panel_container: PanelContainer = $PanelContainer
@onready var time_label: Label = %TimeLabel
@onready var level_xp_label: Label = %LevelXpLabel
@onready var return_button: Button = %ReturnButton
@onready var restart_button: Button = %RestartButton
@onready var upgrades_grid: GridContainer = %UpgradesGrid

@onready var health_label: Label = %GameOverHealthLabel
@onready var shield_label: Label = %GameOverShieldLabel
@onready var regen_label: Label = %GameOverRegenLabel
@onready var speed_label: Label = %GameOverSpeedLabel
@onready var dmg_redux_label: Label = %GameOverDmgReduxLabel
@onready var dmg_mult_label: Label = %GameOverDmgMultLabel
@onready var atk_spd_label: Label = %GameOverAtkSpdLabel
@onready var crit_chance_label: Label = %GameOverCritChanceLabel
@onready var crit_dmg_label: Label = %GameOverCritDmgLabel

var _active_tween: Tween
var _icon_spawn_delay: float = 0.0

var _target_center_pos_y: float = -1.0


func _ready() -> void:
	EntityManager.register_game_over_screen(self)
	return_button.pressed.connect(_on_return_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	hide()
	
	await get_tree().process_frame

	panel_container.pivot_offset = Vector2(panel_container.size.x / 2.0, 0)
	


func show_game_over(time_survived: float, final_stats: PlayerStats, final_upgrades: Dictionary, final_passives: Dictionary, final_level: int, final_xp: float, final_xp_needed: float) -> void:

	_icon_spawn_delay = 0.0

	var minutes: int = floori(time_survived / 60)
	var seconds: int = int(time_survived) % 60
	time_label.text = "Tempo: %02d:%02d" % [minutes, seconds]

	level_xp_label.text = "Nível: %d (XP: %d / %d)" % [final_level, floori(final_xp), floori(final_xp_needed)]

	if final_stats:
		health_label.text = str(final_stats.max_health)
		shield_label.text = str(final_stats.max_shield)
		regen_label.text = str(final_stats.health_regen_rate) + " /s"
		speed_label.text = str(final_stats.speed)
		dmg_redux_label.text = "%.0f%%" % ((1.0 - final_stats.damage_reduction_multiplier) * 100)
		dmg_mult_label.text = "+%.0f%%" % ((final_stats.global_damage_multiplier - 1.0) * 100)
		atk_spd_label.text = "+%.0f%%" % (final_stats.global_attack_speed_bonus * 100)
		crit_chance_label.text = "%.0f%%" % (final_stats.crit_chance * 100)
		crit_dmg_label.text = "x%.1f" % (final_stats.crit_damage)

	_populate_upgrades_grid(final_upgrades, final_passives)

	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	show()

	if _target_center_pos_y == -1.0:
		_target_center_pos_y = panel_container.position.y

	panel_container.modulate.a = 0.0
	panel_container.position.y = -panel_container.size.y
	
	_active_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_active_tween.set_parallel(true)
	
	_active_tween.tween_property(panel_container, "modulate:a", 1.0, 0.4).set_delay(0.2)
	
	_active_tween.tween_property(panel_container, "position:y", _target_center_pos_y, 0.8)


func _populate_upgrades_grid(upgrades_map: Dictionary, passives_map: Dictionary):
	for child in upgrades_grid.get_children():
		child.queue_free()

	_icon_spawn_delay = 0.0 

	var start_id: StringName = &""

	if GameSession.chosen_class and GameSession.chosen_class.starting_ability_scene:
		var starting_scene: PackedScene = GameSession.chosen_class.starting_ability_scene
		var scene_state = starting_scene.get_state()

		if scene_state.get_node_count() > 0:
			for i in range(scene_state.get_node_property_count(0)):
				if scene_state.get_node_property_name(0, i) == "ability_id":
					start_id = scene_state.get_node_property_value(0, i)
					break

		if start_id != &"":
			var available_upgrades = GameManager.available_upgrades
			var found_unlock_upgrade: AbilityUpgrade = null
			for upgrade in available_upgrades:
				if upgrade is AbilityUpgrade and upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY and upgrade.target_ability_id == start_id:
					found_unlock_upgrade = upgrade
					break
			if found_unlock_upgrade:
				_create_upgrade_icon(found_unlock_upgrade)
			else:
				print("Aviso: Upgrade de desbloqueio não encontrado (via get_state) para a habilidade inicial: ", start_id)


	for ability_id in upgrades_map:
		var upgrade_list: Array = upgrades_map[ability_id]
		for upgrade in upgrade_list:
			if upgrade is AbilityUpgrade:
				var is_starting_unlock = false
				if start_id != &"":
					is_starting_unlock = (upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY and upgrade.target_ability_id == start_id)

				if not is_starting_unlock:
					_create_upgrade_icon(upgrade)

	for passive_id in passives_map:
		var upgrade_list: Array = passives_map[passive_id]
		for upgrade in upgrade_list:
			if upgrade is AbilityUpgrade:
				_create_upgrade_icon(upgrade)


func _create_upgrade_icon(upgrade: AbilityUpgrade):
	var icon_instance = UPGRADE_ICON_SCENE.instantiate()
	upgrades_grid.add_child(icon_instance)
	icon_instance.set_upgrade_data(upgrade)

	icon_instance.modulate.a = 0.0
	icon_instance.scale = Vector2(0.7, 0.7)
	icon_instance.pivot_offset = icon_instance.custom_minimum_size / 2.0
	icon_instance.position = icon_instance.custom_minimum_size / 2.0 

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	
	var delay = _icon_spawn_delay + 0.5
	tween.tween_property(icon_instance, "modulate:a", 1.0, 0.3).set_delay(delay)
	tween.tween_property(icon_instance, "scale", Vector2.ONE, 0.3).set_delay(delay)
	
	_icon_spawn_delay += 0.04


func _on_return_button_pressed() -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	_active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_active_tween.set_parallel(true)
	
	_active_tween.tween_property(panel_container, "modulate:a", 0.0, 0.3)
	
	_active_tween.tween_property(panel_container, "position:y", -panel_container.size.y, 0.3)

	await _active_tween.finished

	if GameManager:
		GameManager.unpause_game()
	else:
		get_tree().paused = false
		
	get_tree().change_scene_to_file("res://Scenes/main/main_menu.tscn")

func _on_restart_button_pressed() -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	_active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_active_tween.set_parallel(true)
	
	_active_tween.tween_property(panel_container, "modulate:a", 0.0, 0.3)
	
	_active_tween.tween_property(panel_container, "position:y", -panel_container.size.y, 0.3)

	await _active_tween.finished

	if GameManager:
		GameManager.unpause_game()
	else:
		get_tree().paused = false # Fallback

	get_tree().change_scene_to_file("res://Scenes/main/world.tscn")
