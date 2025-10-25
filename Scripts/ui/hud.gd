extends CanvasLayer

const ABILITY_ICON_SCENE = preload("res://Scenes/ui/hud_hability_placeholder.tscn")

@onready var experience_bar: ProgressBar = $Control/ExperienceContainer/BarWrapper/ExperienceBar
@onready var experience_bar_delayed: ProgressBar = $Control/ExperienceContainer/BarWrapper/ExperienceBarDelayed
@onready var level_label: Label = $Control/ExperienceContainer/BarWrapper/LevelLabel

@onready var health_bar: ProgressBar = $Control/HealthContainer/BarWrapper/HealthBar
@onready var health_bar_delayed: ProgressBar = $Control/HealthContainer/BarWrapper/HealthBarDelayed
@onready var health_label: Label = $Control/HealthContainer/HealthLabel

@onready var shield_bar: ProgressBar = $Control/ShieldContainer/BarWrapper/ShieldBar
@onready var shield_bar_delayed: ProgressBar = $Control/ShieldContainer/BarWrapper/ShieldBarDelayed
@onready var shield_label: Label = $Control/ShieldContainer/ShieldLabel

@onready var time_label: Label = $Control/TimeContainer/TimeLabel
@onready var warning_label: Label = $Control/WarningsContainer/WaveWarningLabel
@onready var money_label: Label = $Control/MoneyContainer/MoneyLabel
@onready var abilities_container: HBoxContainer = $Control/HabilitiesContainer

var _warning_tween: Tween
var _seconds_elapsed: float = 0.0
var _tracked_abilities: Dictionary = {}
var _bar_tweens: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.xp_changed.connect(_on_player_xp_changed)
		player.level_changed.connect(_on_player_level_changed)
		player.health_changed.connect(_on_player_health_changed)
		player.shield_changed.connect(_on_player_shield_changed)
		player.ability_added.connect(_on_ability_added)
		
		if player.has_signal("money_changed"):
			player.money_changed.connect(_on_player_money_changed)
		
		_on_player_health_changed(player.current_health, player.current_stats.max_health)
		_on_player_shield_changed(player.current_shield, player.current_stats.max_shield)
		_on_player_xp_changed(player.current_xp, player.xp_to_next_level)
		
		if player.has_meta("money"):
			_on_player_money_changed(player.get_meta("money"))
		else:
			money_label.text = "$0"
		
		health_bar_delayed.value = health_bar.value
		shield_bar_delayed.value = shield_bar.value
		experience_bar_delayed.value = experience_bar.value

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
		
		var was_on_cooldown: bool = label.visible

		if ability.is_active() or ability.is_on_cooldown():
			label.visible = true
			label.text = "%.1f" % ability.get_time_left()
			var target_color: Color
			if ability.is_active():
				target_color = Color.LIME_GREEN.lightened(0.3)
			else:
				target_color = Color(0.5, 0.5, 0.5, 0.8)
			_tween_icon_modulate(texture, target_color, 0.1)
		else:
			label.visible = false
			_tween_icon_modulate(texture, Color.WHITE, 0.2)
			if was_on_cooldown and not label.visible:
				_animate_icon_ready(texture)


func _on_ability_added(ability: BaseAbility):
	var icon = ABILITY_ICON_SCENE.instantiate()
	var icon_node = icon.find_child("HabilityIcon") as TextureRect
	
	if icon_node:
		if "icon" in ability and ability.icon is Texture2D:
			icon_node.texture = ability.icon
		else:
			print("Aviso: Habilidade %s não tem um ícone definido." % ability.name)
			icon_node.texture = null
	else:
		printerr("Nó 'HabilityIcon' não encontrado em hud_hability_placeholder.tscn")
	abilities_container.add_child(icon)
	_tracked_abilities[ability] = icon
	var texture_to_animate = icon.find_child("HabilityTexture") as TextureRect
	if texture_to_animate:
		texture_to_animate.pivot_offset = texture_to_animate.custom_minimum_size / 2.0
		texture_to_animate.scale = Vector2.ZERO
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(texture_to_animate, "scale", Vector2.ONE, 0.4).set_delay(0.1)

func _on_player_xp_changed(current_xp: float, xp_to_next_level: float) -> void:
	experience_bar.max_value = xp_to_next_level
	experience_bar_delayed.max_value = xp_to_next_level
	experience_bar_delayed.value = current_xp
	_tween_bar(experience_bar, current_xp, 0.3)

func _on_player_level_changed(new_level: int) -> void:
	level_label.text = "Level: " + str(new_level)
	_tween_pop(level_label, 1.5, 0.2)

func _on_player_health_changed(current_health: int, max_health: int):
	health_bar.max_value = max_health
	health_bar_delayed.max_value = max_health
	
	if current_health < health_bar.value:
		health_bar.value = current_health
		_tween_bar(health_bar_delayed, current_health, 0.6, 0.2)
	else:
		health_bar_delayed.value = current_health
		_tween_bar(health_bar, current_health, 0.4)
		
	health_label.text = "%.0f/%.0f" % [current_health, max_health]

func _on_player_money_changed(new_money: int):
	money_label.text = "$" + str(new_money)
	_tween_pop(money_label, 1.3, 0.15)

func _on_player_shield_changed(p_current_shield: float, p_max_shield: float):
	if p_max_shield > 0:
		shield_bar.visible = true
		shield_label.visible = true
		shield_bar_delayed.visible = true
		
		shield_bar.max_value = p_max_shield
		shield_bar_delayed.max_value = p_max_shield

		if p_current_shield < shield_bar.value:
			shield_bar.value = p_current_shield
			_tween_bar(shield_bar_delayed, p_current_shield, 0.5, 0.1)
		else:
			shield_bar_delayed.value = p_current_shield
			_tween_bar(shield_bar, p_current_shield, 0.3)
			
		shield_label.text = "%d/%d" % [roundi(p_current_shield), roundi(p_max_shield)]
	else:
		shield_bar.visible = false
		shield_label.visible = false
		shield_bar_delayed.visible = false

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
	warning_label.scale = Vector2(1.2, 1.2)
	
	_warning_tween.set_parallel(true)
	_warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.5)
	_warning_tween.tween_property(warning_label, "scale", Vector2.ONE, 0.5)
	_warning_tween.set_parallel(false)

	_warning_tween.tween_interval(duration - 1.0)
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.5)
	_warning_tween.tween_callback(func():
		warning_label.visible = false
		_warning_tween = null
	)

func _tween_bar(bar: ProgressBar, new_value: float, duration: float, delay: float = 0.0):
	if _bar_tweens.has(bar) and is_instance_valid(_bar_tweens[bar]):
		_bar_tweens[bar].kill()
		
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "value", new_value, duration).set_delay(delay)
	_bar_tweens[bar] = tween

func _tween_pop(node: Control, p_scale: float = 1.3, p_duration: float = 0.15):
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE * p_scale, p_duration / 2.0)
	tween.tween_property(node, "scale", Vector2.ONE, p_duration / 2.0)

func _animate_ability_ready(texture: TextureRect):
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var duration = 0.12
	tween.set_parallel()
	tween.tween_property(texture, "scale", Vector2(1.3, 1.3), duration)
	tween.tween_property(texture, "modulate", Color.WHITE.lightened(0.7), duration)
	
	tween.chain().set_parallel()
	tween.tween_property(texture, "scale", Vector2.ONE, duration)
	tween.tween_property(texture, "modulate", Color.WHITE, duration)
	
func _tween_icon_modulate(node: TextureRect, color: Color, duration: float):
	if node.modulate == color:
		return
	var tween_name = "modulate_tween"
	if node.has_meta(tween_name):
		var old_tween = node.get_meta(tween_name)
		if is_instance_valid(old_tween):
			old_tween.kill()
	var tween = create_tween()
	tween.tween_property(node, "modulate", color, duration)
	node.set_meta(tween_name, tween)

func _animate_icon_ready(texture: TextureRect):
	if texture.pivot_offset == Vector2.ZERO:
		texture.pivot_offset = texture.custom_minimum_size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var duration = 0.6
	tween.tween_property(texture, "scale", Vector2(1.3, 1.3), duration * 0.7)
	tween.chain().tween_property(texture, "scale", Vector2.ONE, duration * 0.3)
	var flash_tween = create_tween()
	var flash_color = Color.WHITE.lightened(0.7)
	flash_tween.tween_property(texture, "modulate", flash_color, 0.1)
	flash_tween.chain().tween_property(texture, "modulate", Color.WHITE, 0.1)
