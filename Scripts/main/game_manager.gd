# Scripts/GameManager.gd
extends Node

# --- Referências de Nós ---
var upgrade_screen: CanvasLayer 
var player: CharacterBody2D

# --- Variáveis ---
var available_upgrades: Array[AbilityUpgrade] = []
var is_game_paused: bool = false
var _is_upgrade_signal_connected: bool = false

func _ready() -> void:
	_load_upgrades_from_disk()

# --- Funções Públicas ---
func pause_game():
	is_game_paused = true
	get_tree().paused = true
	print("Jogo Pausado")

func unpause_game():
	is_game_paused = false
	get_tree().paused = false
	print("Jogo Despausado")
	
func begin_level_up():
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			printerr("GameManager: Tentou iniciar level up, mas o Jogador não foi encontrado!")
			return

	if not is_instance_valid(upgrade_screen):
		upgrade_screen = get_tree().get_first_node_in_group("upgrade_screen_group")
		if not upgrade_screen:
			printerr("GameManager: Tentou iniciar level up, mas a Tela de Upgrade não foi encontrada!")
			return
	
	if not _is_upgrade_signal_connected:
		upgrade_screen.upgrade_selected.connect(on_upgrade_chosen)
		_is_upgrade_signal_connected = true

	pause_game()
	
	var upgrade_pool: Array[AbilityUpgrade] = []
	var player_abilities: Array[StringName] = player.active_abilities.keys()
	
	# --- DEFINA OS PESOS AQUI ---
	var ability_upgrade_weight = 3 # Upgrades de habilidade são 3x mais prováveis
	var new_ability_weight = 5     # Desbloquear novas habilidades é ainda mais provável
	var passive_upgrade_weight = 1 # Passivas têm peso base
	# ---------------------------

	for upgrade in available_upgrades:
		
		# HABILIDADES EXISTENTES
		if upgrade.type == AbilityUpgrade.UpgradeType.UPGRADE_EXISTING_ABILITY:
			if upgrade.target_ability_id in player_abilities:
				# Adiciona múltiplas vezes baseado no peso
				for i in range(ability_upgrade_weight):
					upgrade_pool.append(upgrade)
					
		# NOVAS HABILIDADES
		elif upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY:
			if player.has_empty_ability_slot() and not upgrade.target_ability_id in player_abilities:
				# Adiciona múltiplas vezes baseado no peso
				for i in range(new_ability_weight):
					upgrade_pool.append(upgrade)
					
		# PASSIVAS
		elif upgrade.type == AbilityUpgrade.UpgradeType.APPLY_PASSIVE_STAT:
			var stat_id = upgrade.passive_stat_id
			# Verifica se é um stat novo (e tem slot) OU se é um stat existente (stack)
			if (not player.active_passives.has(stat_id) and player.has_empty_passive_slot()) or \
			   player.active_passives.has(stat_id):
			   	# Adiciona múltiplas vezes baseado no peso (apenas 1 vez neste caso)
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

# --- Funções Privadas ---
func _load_upgrades_from_disk() -> void:
	available_upgrades.clear()
	_recursive_scan_for_upgrades("res://Upgrades")
	print("Carregados %d upgrades." % available_upgrades.size())

func _recursive_scan_for_upgrades(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		printerr("Diretório de Upgrades não encontrado em: " + path)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path = path.path_join(file_name)

		if dir.current_is_dir():
			_recursive_scan_for_upgrades(full_path)
		# --- CORREÇÃO PRINCIPAL AQUI ---
		# Verifica se o arquivo termina com .tres ou .tres.remap
		elif file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			# No jogo exportado, precisamos remover o ".remap" para que o 'load' funcione
			if full_path.ends_with(".remap"):
				full_path = full_path.trim_suffix(".remap")
				
			var upgrade = load(full_path)
			if upgrade is AbilityUpgrade:
				available_upgrades.append(upgrade)
		
		file_name = dir.get_next()
