# Scripts/Skills/base_ability.gd
class_name BaseAbility
extends Node2D

# --- Sinais ---
signal on_cooldown_started
signal on_cooldown_finished
signal on_deactivated

# --- Propriedades Padrão ---
@export var ability_id: StringName
@export var cooldown_time: float = 1.0
@export var active_duration: float = 0.0
@export var damage_amount: int = 1
@export var requires_aiming: bool = false
@export var aim_at_closest_enemy: bool = true

# --- Variáveis Internas ---
var cooldown_modifier: float = 1.0
var total_attack_speed_multiplier: float = 1.0
var _cooldown_timer: Timer # <-- Declarado aqui
var _active_duration_timer: Timer # <-- Declarado aqui
var _is_unavailable: bool = false
var player: Node = null

# --- CORREÇÃO 1: Criar timers no _init() ---
# A função _init() é chamada quando o nó é criado, ANTES de _ready()
func _init() -> void:
	# Cria os timers imediatamente
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	# Conectamos os sinais aqui também
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer) # Adiciona como filho

	_active_duration_timer = Timer.new()
	_active_duration_timer.one_shot = true
	_active_duration_timer.timeout.connect(_on_active_duration_finished)
	add_child(_active_duration_timer) # Adiciona como filho
# ----------------------------------------

# _ready() agora só chama a função de setup da habilidade filha
func _ready() -> void:
	player = get_owner()
	_ability_ready() # Chama a função que pode ser sobrescrita

# Função vazia para ser sobrescrita pelas habilidades filhas
func _ability_ready() -> void:
	pass

# Função vazia para ser sobrescrita pelas habilidades filhas
func _on_activate(_params: Dictionary) -> void:
	push_error("A função '_on_activate' deve ser implementada pela habilidade filha!")

func activate(params: Dictionary = {}) -> void:
	if _is_unavailable:
		return

	_is_unavailable = true
	_on_activate(params) # Chama a implementação da filha

	if active_duration > 0:
		# Timer já existe, apenas configura e inicia
		_active_duration_timer.wait_time = active_duration
		_active_duration_timer.start()
	else:
		# Chama DEPOIS do frame atual para garantir ordem correta
		call_deferred("_on_active_duration_finished")

# --- CORREÇÃO 2: Adicionar checagem em is_active() ---
func is_active() -> bool:
	# Adiciona uma checagem para garantir que o timer existe
	if not is_instance_valid(_active_duration_timer):
		return false # Se não existe, não está ativo
	return not _active_duration_timer.is_stopped() # Linha 65 (aprox.)
# --------------------------------------------------

func _on_active_duration_finished():
	on_deactivated.emit()
	
	# A checagem aqui ainda é útil como segurança extra
	if not is_instance_valid(_cooldown_timer):
		push_error("Cooldown timer não está pronto em _on_active_duration_finished! (Isso não deveria acontecer)")
		_is_unavailable = false
		on_cooldown_finished.emit()
		return

	var final_cooldown = max(0.01, cooldown_time / total_attack_speed_multiplier) * cooldown_modifier
	if final_cooldown > 0:
		_cooldown_timer.wait_time = final_cooldown
		_cooldown_timer.start()
		on_cooldown_started.emit()
	else:
		_on_cooldown_timeout()

func _on_cooldown_timeout() -> void:
	_is_unavailable = false
	on_cooldown_finished.emit()

# --- CORREÇÃO 3: Adicionar checagem em is_on_cooldown() ---
func is_on_cooldown() -> bool:
	# Adiciona uma checagem para garantir que o timer existe
	if not is_instance_valid(_cooldown_timer):
		return false # Se não existe, não está em cooldown
	return not _cooldown_timer.is_stopped()
# -----------------------------------------------------

# --- CORREÇÃO 4: Adicionar checagem em get_time_left() ---
func get_time_left() -> float:
	# Adiciona checagens para garantir que os timers existem
	if is_instance_valid(_active_duration_timer) and not _active_duration_timer.is_stopped():
		return _active_duration_timer.time_left
	if is_instance_valid(_cooldown_timer) and not _cooldown_timer.is_stopped():
		return _cooldown_timer.time_left
	return 0.0
# ------------------------------------------------------
