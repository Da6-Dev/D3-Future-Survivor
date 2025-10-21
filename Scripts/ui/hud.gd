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
var _tracked_abilities: Dictionary = {} # Guarda {ability_instance: icon_instance}

func _ready() -> void:
	# Espera um frame para garantir que o player já existe na cena
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Conexões existentes
		player.xp_changed.connect(_on_player_xp_changed)
		player.level_changed.connect(_on_player_level_changed)
		player.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(player.current_health, player.max_health)
		player.shield_changed.connect(_on_player_shield_changed)
		
		# Nova conexão para habilidades
		player.ability_added.connect(_on_ability_added)
		
		# Adiciona ícones para habilidades que o jogador já possa ter no início
		for ability in player.active_abilities.values():
			_on_ability_added(ability)

func _process(delta: float) -> void:
	# Atualiza o cronômetro
	_seconds_elapsed += delta
	var minutes: int = floori(_seconds_elapsed / 60)
	var seconds: int = int(_seconds_elapsed) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

	# Atualiza os contadores de cooldown no HUD
	for ability in _tracked_abilities:
		var icon = _tracked_abilities[ability]
		var label: Label = icon.find_child("CooldownLabel")
		var texture: TextureRect = icon.find_child("HabilityTexture")
		
		if not is_instance_valid(label): continue

		if ability.is_active() or ability.is_on_cooldown():
			label.visible = true
			label.text = "%.1f" % ability.get_time_left()
			
			# Feedback visual: verde se estiver ativa, branco se estiver em cooldown
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
	# Aqui você poderia adicionar lógica para carregar a textura correta para o ícone
	# com base no 'ability.ability_id'

func _on_player_xp_changed(current_xp: float, xp_to_next_level: float) -> void:
	experience_bar.max_value = xp_to_next_level
	experience_bar.value = current_xp

func _on_player_level_changed(new_level: int) -> void:
	level_label.text = "Level: " + str(new_level)

func _on_player_health_changed(current_health: int, max_health: int):
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_label.text = "%d/%d" % [current_health, max_health]

func show_warning(text: String, duration: float = 2.5):
	if not is_instance_valid(warning_label):
		print("AVISO SPAWNER: ", text)
		return
	print("show_warning chamado com texto: ", text) # Print para depuração

	warning_label.text = text
	warning_label.visible = true

	# --- CORREÇÃO DA LÓGICA DO TWEEN ---
	# 1. Mata o tween anterior, se ele existir
	if is_instance_valid(_warning_tween):
		_warning_tween.kill()

	# 2. Cria o novo tween e guarda na variável
	_warning_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# (Não precisamos mais adicionar como filho do label)
	# ------------------------------------

	warning_label.modulate = Color(1,1,1,0)
	_warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.5)
	_warning_tween.tween_interval(duration - 1.0)
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.5)
	_warning_tween.tween_callback(func():
		warning_label.visible = false
		# Define a variável como inválida quando o tween terminar
		_warning_tween = null
	)

func _on_player_shield_changed(p_current_shield: float, p_max_shield: float):
	if p_max_shield > 0: # Mostra a barra só se o jogador tiver escudo
		shield_bar.visible = true
		shield_label.visible = true
		shield_bar.max_value = p_max_shield
		shield_bar.value = p_current_shield
		shield_label.text = "%d/%d" % [roundi(p_current_shield), roundi(p_max_shield)]
	else:
		shield_bar.visible = false
		shield_label.visible = false
