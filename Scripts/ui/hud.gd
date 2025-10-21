extends CanvasLayer

const ABILITY_ICON_SCENE = preload("res://Scenes/ui/hud_hability_placeholder.tscn")

@onready var experience_bar: ProgressBar = $Control/ExperienceContainer/ExperienceBar
@onready var level_label: Label = $Control/ExperienceContainer/ExperienceBar/LevelLabel
@onready var health_bar: ProgressBar = $Control/HealthContainer/HealthBar
@onready var health_label: Label = $Control/HealthContainer/HealthLabel
@onready var time_label: Label = $Control/TimeContainer/TimeLabel
@onready var abilities_container: HBoxContainer = $Control/HabilitiesContainer
@onready var warning_label: Label = $Control/WarningsContainer/WaveWarningLabel
@onready var shield_bar: ProgressBar = $Control/ShieldContainer/ShieldBar
@onready var shield_label: Label = $Control/ShieldContainer/ShieldLabel

var _warning_tween: Tween
var _seconds_elapsed: float = 0.0
var _tracked_abilities: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.xp_changed.connect(_on_player_xp_changed)
		player.level_changed.connect(_on_player_level_changed)
		player.health_changed.connect(_on_player_health_changed)
		
		# --- CORREÇÃO AQUI ---
		# Lemos o max_health de 'current_stats'
		_on_player_health_changed(player.current_health, player.current_stats.max_health)
		# ---------------------
		
		player.shield_changed.connect(_on_player_shield_changed)
		player.ability_added.connect(_on_ability_added)
		
		for ability in player.active_abilities.values():
			_on_ability_added(ability)

func _process(delta: float) -> void:
	_seconds_elapsed += delta
	var minutes: int = floori(_seconds_elapsed / 60)
	var seconds: int = int(_seconds_elapsed) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

	for ability in _tracked_abilities:
		var icon = _tracked_abilities[ability]
		var label: Label = icon.find_child("CooldownLabel")
		var texture: TextureRect = icon.find_child("HabilityTexture")
		
		if not is_instance_valid(label): continue

		if ability.is_active() or ability.is_on_cooldown():
			label.visible = true
			label.text = "%.1f" % ability.get_time_left()
			
			if ability.is_active():
				texture.modulate = Color.LIME_GREEN
			else:
				texture.modulate = Color.WHITE
		else:
			label.visible = false
			texture.modulate = Color.WHITE

func _on_ability_added(ability: BaseAbility):
	var icon = ABILITY_ICON_SCENE.instantiate()
	abilities_container.add_child(icon)
	_tracked_abilities[ability] = icon

func _on_player_xp_changed(current_xp: float, xp_to_next_level: float) -> void:
	experience_bar.max_value = xp_to_next_level
	experience_bar.value = current_xp

func _on_player_level_changed(new_level: int) -> void:
	level_label.text = "Level: " + str(new_level)

func _on_player_health_changed(current_health: int, max_health: int):
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "%.0f/%.0f" % [current_health, max_health]

func show_warning(text: String, duration: float = 2.5):
	if not is_instance_valid(warning_label):
		return
	EntityManager.trigger_shake(5.0, duration, 5.0)
	warning_label.text = text
	warning_label.visible = true

	if is_instance_valid(_warning_tween):
		_warning_tween.kill()

	_warning_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	warning_label.modulate = Color(1,1,1,0)
	_warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.5)
	_warning_tween.tween_interval(duration - 1.0)
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.5)
	_warning_tween.tween_callback(func():
		warning_label.visible = false
		_warning_tween = null
	)

func _on_player_shield_changed(p_current_shield: float, p_max_shield: float):
	if p_max_shield > 0:
		shield_bar.visible = true
		shield_label.visible = true
		shield_bar.max_value = p_max_shield
		shield_bar.value = p_current_shield
		shield_label.text = "%d/%d" % [roundi(p_current_shield), roundi(p_max_shield)]
	else:
		shield_bar.visible = false
		shield_label.visible = false
