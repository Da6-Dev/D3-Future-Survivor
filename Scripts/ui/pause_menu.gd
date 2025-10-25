extends CanvasLayer

signal settings_pressed

const UPGRADE_ICON_SCENE = preload("res://Scenes/ui/upgrade_display_icon.tscn")

@onready var panel_container: PanelContainer = $PanelContainer
@onready var resume_button: Button = $PanelContainer/HBoxContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $PanelContainer/HBoxContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $PanelContainer/HBoxContainer/VBoxContainer/QuitButton

@onready var level_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/LevelLabel
@onready var xp_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/XpLabel
@onready var health_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/HealthLabel
@onready var shield_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/ShieldLabel
@onready var regen_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/RegenLabel
@onready var speed_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/SpeedLabel
@onready var dmg_redux_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/DmgReduxLabel
@onready var dmg_mult_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/DmgMultLabel
@onready var atk_spd_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/AtkSpdLabel
@onready var crit_chance_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/CritChanceLabel
@onready var crit_dmg_label: Label = $PanelContainer/HBoxContainer/StatsPanelContainer/MarginContainer/VBoxContainer/StatsGridContainer/CritDmgLabel
@onready var upgrades_grid: GridContainer = $PanelContainer/HBoxContainer/UpgradesPanelContainer/MarginContainer/VBoxContainer/ScrollContainer/UpgradesGrid
@onready var quit_confirmation_dialog: ConfirmationDialog = $QuitConfirmationDialog

var _active_tween: Tween
var _last_focused_control: Control = null

func _ready() -> void:
	EntityManager.register_pause_menu(self)
	
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	quit_confirmation_dialog.confirmed.connect(_on_quit_confirmed)

	await get_tree().process_frame
	
	panel_container.pivot_offset = panel_container.size / 2.0


func open_menu():
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	show()
	_update_stats_display() 

	panel_container.modulate.a = 0.0
	panel_container.scale = Vector2(0.9, 0.9)

	_active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.set_parallel(true)
	
	_active_tween.tween_property(panel_container, "modulate:a", 1.0, 0.3)
	_active_tween.tween_property(panel_container, "scale", Vector2.ONE, 0.3)
	
	_last_focused_control = get_viewport().gui_get_focus_owner()
	resume_button.call_deferred("grab_focus")


func _update_stats_display():
	var player = EntityManager.get_player()

	if not is_instance_valid(player) or not player.current_stats:
		level_label.text = "N/A"
		xp_label.text = "N/A"
		health_label.text = "N/A"
		shield_label.text = "N/A"
		regen_label.text = "N/A"
		speed_label.text = "N/A"
		dmg_redux_label.text = "N/A"
		dmg_mult_label.text = "N/A"
		atk_spd_label.text = "N/A"
		crit_chance_label.text = "N/A"
		crit_dmg_label.text = "N/A"
		for child in upgrades_grid.get_children():
			child.queue_free()
		return

	var stats: PlayerStats = player.current_stats

	level_label.text = str(player.level)
	xp_label.text = "%d / %d" % [player.current_xp, player.xp_to_next_level]
	health_label.text = str(stats.max_health)
	shield_label.text = str(stats.max_shield)
	regen_label.text = str(stats.health_regen_rate) + " /s"
	speed_label.text = str(stats.speed)

	dmg_redux_label.text = "%.0f%%" % ((1.0 - stats.damage_reduction_multiplier) * 100)
	dmg_mult_label.text = "+%.0f%%" % ((stats.global_damage_multiplier - 1.0) * 100)
	atk_spd_label.text = "+%.0f%%" % (stats.global_attack_speed_bonus * 100)
	crit_chance_label.text = "%.0f%%" % (stats.crit_chance * 100)
	crit_dmg_label.text = "x%.1f" % (stats.crit_damage)

	_populate_upgrades_grid(player)


func _populate_upgrades_grid(player: Node2D):
	for child in upgrades_grid.get_children():
		child.queue_free()

	var delay_time: float = 0.0

	if GameSession.chosen_class and GameSession.chosen_class.starting_ability_scene:
		var starting_scene: PackedScene = GameSession.chosen_class.starting_ability_scene
		var temp_ability_instance = starting_scene.instantiate()

		if temp_ability_instance is BaseAbility:
			var starting_ability_id = temp_ability_instance.ability_id
			var available_upgrades = GameManager.available_upgrades
			var found_unlock_upgrade: AbilityUpgrade = null

			for upgrade in available_upgrades:
				if upgrade is AbilityUpgrade:
					if upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY and \
					   upgrade.target_ability_id == starting_ability_id:
						found_unlock_upgrade = upgrade
						break

			if found_unlock_upgrade:
				_create_upgrade_icon(found_unlock_upgrade, delay_time)
				delay_time += 0.04
			else:
				print("Aviso: Upgrade de desbloqueio não encontrado para a habilidade inicial: ", starting_ability_id)

		temp_ability_instance.queue_free()

	for ability_id in player.applied_upgrades_map:
		var upgrade_list: Array = player.applied_upgrades_map[ability_id]
		for upgrade in upgrade_list:
			if upgrade is AbilityUpgrade:
				var is_starting_unlock = false
				if GameSession.chosen_class and GameSession.chosen_class.starting_ability_scene:
					var temp_instance = GameSession.chosen_class.starting_ability_scene.instantiate() as BaseAbility
					if temp_instance:
						is_starting_unlock = (upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY and upgrade.target_ability_id == temp_instance.ability_id)
						temp_instance.queue_free()
				
				if not is_starting_unlock:
					_create_upgrade_icon(upgrade, delay_time)
					delay_time += 0.04


	for passive_id in player.active_passives:
		var upgrade_list: Array = player.active_passives[passive_id]
		for upgrade in upgrade_list:
			if upgrade is AbilityUpgrade:
				_create_upgrade_icon(upgrade, delay_time)
				delay_time += 0.04


func _create_upgrade_icon(upgrade: AbilityUpgrade, delay: float = 0.0):
	var icon_instance = UPGRADE_ICON_SCENE.instantiate()
	upgrades_grid.add_child(icon_instance)
	icon_instance.set_upgrade_data(upgrade)

	icon_instance.modulate.a = 0.0
	icon_instance.scale = Vector2(0.7, 0.7)
	icon_instance.pivot_offset = icon_instance.custom_minimum_size / 2.0
	icon_instance.position = icon_instance.custom_minimum_size / 2.0

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(icon_instance, "modulate:a", 1.0, 0.3).set_delay(delay)
	tween.tween_property(icon_instance, "scale", Vector2.ONE, 0.3).set_delay(delay)


func _unhandled_input(event: InputEvent) -> void:
	# *** CORREÇÃO AQUI ***
	# Trocado de 'event.is_action_just_pressed' para 'event.is_action' + 'event.is_pressed'
	if event.is_action("ui_pause") and event.is_pressed() and not event.is_echo() and visible:
		if not quit_confirmation_dialog.visible:
			_on_resume_pressed()
			get_viewport().set_input_as_handled()


func _on_resume_pressed():
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	_active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_active_tween.set_parallel(true)
	
	_active_tween.tween_property(panel_container, "modulate:a", 0.0, 0.2)
	_active_tween.tween_property(panel_container, "scale", Vector2(0.9, 0.9), 0.2)

	await _active_tween.finished
	
	hide()
	GameManager.unpause_game()
	
	if is_instance_valid(_last_focused_control):
		_last_focused_control.call_deferred("grab_focus")
	_last_focused_control = null

func _on_quit_button_pressed():
	quit_confirmation_dialog.popup_centered()

func _on_quit_confirmed():
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
		
	_last_focused_control = null # Limpa o foco ao sair

	_active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_active_tween.set_parallel(true)
	_active_tween.tween_property(panel_container, "modulate:a", 0.0, 0.2)
	_active_tween.tween_property(panel_container, "scale", Vector2(0.9, 0.9), 0.2)
	
	await _active_tween.finished

	GameManager.unpause_game()
	get_tree().change_scene_to_file("res://Scenes/main/main_menu.tscn")

func _on_settings_pressed():
	emit_signal("settings_pressed")
	hide()
