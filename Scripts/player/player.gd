# scripts/player/player.gd
extends CharacterBody2D

signal xp_changed(current_xp: float, xp_to_next_level: float)
signal level_changed(new_level: int)
signal health_changed(current_health: int, max_health: int)
signal died
signal ability_added(ability: BaseAbility)
signal shield_changed(current_shield: float, max_shield: float)

@export var speed: float = 300.0

@export_group("Stats")
@export var max_health: int = 100
@export var ability_slots: int = 3
@export var passive_slots: int = 4

@export_group("Damage Feedback")
@export var invincibility_duration: float = 0.5
@export var flash_color: Color = Color.RED

# --- MUDANÇA 1: Referência do Nó ---
# Trocamos 'visual: Sprite2D' por 'animations: AnimatedSprite2D'
@onready var animations: AnimatedSprite2D = $PlayerAnimations
# ------------------------------------

@onready var collision_shape: CollisionShape2D = $PhysicalCollision
@onready var invincibility_timer: Timer = $InvincibilityTimer

var active_abilities: Dictionary[StringName, BaseAbility] = {}
var active_passives: Dictionary = {}

var global_damage_multiplier: float = 1.0
var global_attack_speed_bonus: float = 0.0
var crit_chance: float = 0.0 # Chance de crítico (0.0 = 0%, 0.1 = 10%)
var crit_damage: float = 2.0 # Multiplicador do dano (2.0 = 200% de dano)
var damage_reduction_multiplier: float = 1.0
var health_regen_rate: float = 0.0
var _health_regen_accumulator: float = 0.0
var max_shield: float = 0.0
var current_shield: float = 0.0
var shield_recharge_delay: float = 5.0 # Tempo (segundos) sem tomar dano para recarregar
var shield_recharge_rate: float = 10.0 # Pontos de escudo recuperados por segundo
@onready var shield_recharge_timer: Timer = $ShieldRechargeTimer # Nó Timer que adicionaremos

# --- NOVO DICIONÁRIO PARA GUARDAR UPGRADES ---
# Formato: { ability_id: [ upgrade_resource_1, upgrade_resource_2, ... ] }
var applied_upgrades_map: Dictionary = {}
# -------------------------------------------

var last_direction: Vector2 = Vector2.RIGHT
var _is_invincible: bool = false
var current_health: int
var current_xp: float = 0.0
var xp_to_next_level: float = 3.0
var level: int = 1

# --- MUDANÇA 2: Estado de Morte ---
# Adicionamos isso para travar as animações ao morrer
var _is_dead: bool = false
# ----------------------------------

func _ready() -> void:
	if GameSession.chosen_class:
		_apply_class_data(GameSession.chosen_class)
	else:
		printerr("Nenhuma classe foi selecionada! Carregando uma classe padrão.")
		var fallback_class = load("res://Classes/guerreiro.tres")
		_apply_class_data(fallback_class)
	
	update_last_direction_from_input()
	invincibility_timer.wait_time = invincibility_duration
	invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)
	shield_recharge_timer.timeout.connect(_on_shield_recharge_timer_timeout)
	
	health_changed.emit(current_health, max_health)
	xp_changed.emit(current_xp, xp_to_next_level)
	level_changed.emit(level)
	shield_changed.emit(current_shield, max_shield)

func _physics_process(delta: float) -> void:
	# Se estiver morto, para de processar
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if health_regen_rate > 0.0 and current_health < max_health:
		# Acumula a cura fracionada
		_health_regen_accumulator += health_regen_rate * delta

		# Se acumulamos 1 ponto de vida ou mais...
		if _health_regen_accumulator >= 1.0:
			var heal_amount = floori(_health_regen_accumulator) # Pega a parte inteira
			_health_regen_accumulator -= heal_amount # Subtrai a parte inteira do acumulador

			# Aplica a cura inteira à vida atual
			current_health += heal_amount
			current_health = min(current_health, max_health) # Garante que não ultrapasse o máximo

			# Emite o sinal para atualizar o HUD
			health_changed.emit(current_health, max_health)
	
	if max_shield > 0.0 and current_shield < max_shield and shield_recharge_timer.is_stopped():
		current_shield += shield_recharge_rate * delta
		current_shield = min(current_shield, max_shield)
		shield_changed.emit(current_shield, max_shield)
	
	if _is_invincible:
		# Lógica de knockback
		velocity = velocity.move_toward(Vector2.ZERO, speed / 2)
	else:
		# Lógica de movimento normal
		handle_movement()
	
	move_and_slide()
	
	# --- MUDANÇA 3: Atualizar Animações ---
	# Chamamos a função que decide qual animação tocar
	_update_animations()
	# ------------------------------------

	# Lógica de mira (sem alterações)
	for id in active_abilities:
		var ability = active_abilities[id]
		if not is_instance_valid(ability):
			continue
		if ability.requires_aiming:
			var attack_direction = last_direction
			if ability.aim_at_closest_enemy:
				var closest_enemy = _find_closest_enemy()
				if is_instance_valid(closest_enemy):
					attack_direction = (closest_enemy.global_position - global_position).normalized()
			ability.activate({"attack_angle": attack_direction.angle()})
		else:
			ability.activate()

# --- MUDANÇA 4: Nova Função de Animação ---
func _update_animations() -> void:
	# Se a animação de "Hurt" estiver tocando, deixa ela terminar
	if animations.animation == "Hurt" and animations.is_playing():
		return

	# Lógica de Idle/Run
	if velocity.length_squared() > 0:
		animations.play("Run")
	else:
		animations.play("Idle")

	# Lógica de Virar (Flip)
	if last_direction.x != 0:
		animations.flip_h = (last_direction.x < 0)
# -----------------------------------------

func _find_closest_enemy() -> CharacterBody2D:
	var closest_enemy: CharacterBody2D = null
	var min_dist_sq = INF 
	var enemies_on_screen = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies_on_screen:
		var dist_sq = global_position.distance_squared_to(enemy.global_position)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_enemy = enemy
			
	return closest_enemy

func _apply_class_data(class_data: PlayerClass):
	self.max_health = class_data.max_health
	self.current_health = self.max_health
	self.speed = class_data.speed

	if class_data.starting_ability_scene is PackedScene:
		var ability_instance: BaseAbility = class_data.starting_ability_scene.instantiate()
		add_child(ability_instance)
		ability_instance.total_attack_speed_multiplier += global_attack_speed_bonus
		
		var id = ability_instance.ability_id
		if id == &"":
			push_error("A habilidade instanciada não tem um 'ability_id'!")
			return
			
		active_abilities[id] = ability_instance
		emit_signal("ability_added", ability_instance)
	else:
		push_error("A cena da habilidade inicial da classe é inválida.")

func handle_movement() -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length() > 0:
		last_direction = input_direction.normalized()
	velocity = input_direction * speed

func update_last_direction_from_input() -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length() > 0:
		last_direction = input_direction.normalized()
	else:
		last_direction = Vector2.RIGHT

func apply_upgrade(upgrade: AbilityUpgrade):
	# --- GUARDA O UPGRADE NO DICIONÁRIO ---
	var target_id = upgrade.target_ability_id
	if not applied_upgrades_map.has(target_id):
		applied_upgrades_map[target_id] = []
	# Guarda o RECURSO do upgrade, não apenas o ID
	applied_upgrades_map[target_id].append(upgrade)
	# -------------------------------------

	if upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY:
		# ... (lógica de unlock permanece igual) ...
		var scene_to_load = upgrade.new_ability_scene
		if scene_to_load is PackedScene:
			var ability_instance: BaseAbility = scene_to_load.instantiate()
			add_child(ability_instance)
			ability_instance.total_attack_speed_multiplier += global_attack_speed_bonus
			var id = ability_instance.ability_id
			active_abilities[id] = ability_instance
			print("Habilidade Desbloqueada: ", upgrade.ability_name)
			emit_signal("ability_added", ability_instance)
		else:
			push_error("Falha ao desbloquear habilidade: a cena não é válida.")

	elif upgrade.type == AbilityUpgrade.UpgradeType.UPGRADE_EXISTING_ABILITY:
		var target_ability = active_abilities.get(upgrade.target_ability_id)

		if is_instance_valid(target_ability):
			var needs_special_handling = false
			var needs_timer_update = false # <-- Nova flag

			for key in upgrade.modifiers:
				var modifier_value = upgrade.modifiers[key]

				# --- NOVA LÓGICA DE MULTIPLICADOR ---
				if key == "attack_speed_multiplier":
					var current_mult = target_ability.get("total_attack_speed_multiplier")
					target_ability.set("total_attack_speed_multiplier", current_mult + modifier_value)
					needs_timer_update = true # Marcar para atualizar os timers
					print("Upgrade Multiplicador Aplicado: ", key, " em ", upgrade.ability_name)
				# ------------------------------------
				elif not key in target_ability:
					# (Ignora propriedades da torreta, etc.)
					continue 

				else:
					# Lógica antiga para dano, raio, contagem, etc.
					var current_value = target_ability.get(key)
					target_ability.set(key, current_value + modifier_value)
					print("Upgrade Direto Aplicado: ", key, " em ", upgrade.ability_name)

				# Lógica de regeneração (permanece igual)
				if key == "sword_count" or key == "radius" or key == "drone_count":
					needs_special_handling = true

			if needs_special_handling:
				if target_ability.has_method("regenerate_swords"):
					target_ability.regenerate_swords()
				if target_ability.has_method("update_radius"):
					target_ability.update_radius()
				if target_ability.has_method("regenerate_drones"):
					target_ability.regenerate_drones()

			# --- NOVO BLOCO ADICIONADO ---
			# (Chama a nova função em habilidades como 'DefensiveAura')
			if needs_timer_update:
				if target_ability.has_method("update_timers"):
					target_ability.update_timers()
	elif upgrade.type == AbilityUpgrade.UpgradeType.APPLY_PASSIVE_STAT:
		var stat_id = upgrade.passive_stat_id
		
		if not active_passives.has(stat_id):
			# É a PRIMEIRA vez que pega este stat (ex: "stat_health").
			# Precisamos verificar se há um slot passivo livre.
			if has_empty_passive_slot():
				active_passives[stat_id] = [upgrade] # Cria um novo array com este upgrade
				_apply_passive_stat(upgrade) # Aplica o bônus
				print("Nova passiva '%s' adicionada." % stat_id)
			else:
				push_error("Tentou adicionar nova passiva '%s' mas não há slots livres." % stat_id)
		else:
			# Já temos este stat (ex: "stat_health").
			# Estamos EMPILHANDO (stacking). Não é preciso checar slots.
			
			# Apenas adicionamos o upgrade ao nosso array de rastreamento
			active_passives[stat_id].append(upgrade)
			
			# E, o mais importante, APLICAMOS O BÔNUS (esta é a correção)
			_apply_passive_stat(upgrade) 
			
			print("Passiva '%s' empilhada com '%s'." % [stat_id, upgrade.id])
	
func _apply_passive_stat(upgrade: AbilityUpgrade):
	print("Aplicando passiva: ", upgrade.ability_name)

	for key in upgrade.modifiers:
		var modifier_value = upgrade.modifiers[key]

		match key:
			"max_health":
				var health_gain = int(modifier_value)
				max_health += health_gain
				current_health += health_gain # Cura o jogador pelo valor ganho
				health_changed.emit(current_health, max_health)
				print("  -> Vida Máxima aumentada em ", health_gain)

			"speed":
				var speed_gain = float(modifier_value)
				speed += speed_gain
				print("  -> Velocidade aumentada em ", speed_gain)
				
			"global_damage":
				var damage_increase_percent = float(modifier_value)
				global_damage_multiplier += damage_increase_percent

				# (Removemos a lógica de aplicar em habilidades ativas,
				#  pois agora o cálculo é feito em tempo real)

				print("  -> Dano Global aumentado em %s%%" % (damage_increase_percent * 100))
				
			"attack_speed":
				var speed_increase_percent = float(modifier_value)
				global_attack_speed_bonus += speed_increase_percent
				
				# Aplica o bônus a todas as habilidades JÁ ATIVAS
				for ability in active_abilities.values():
					# 1. Aplica o bônus diretamente no multiplicador da habilidade
					ability.total_attack_speed_multiplier += speed_increase_percent
					
					# 2. Agora o PLAYER checa se a 'ability' tem o método e o chama
					if ability.has_method("update_timers"):
						ability.update_timers() # Chama a função NA HABILIDADE (ex: na DefensiveAura)
						
				print("  -> Velocidade de Ataque Global aumentada em %s%%" % (speed_increase_percent * 100))
				
			"crit_chance":
				var crit_increase_percent = float(modifier_value)
				crit_chance += crit_increase_percent
				print("  -> Chance de Crítico aumentada em %s%%" % (crit_increase_percent * 100))
				
			"crit_damage":
				var crit_damage_increase = float(modifier_value)
				crit_damage += crit_damage_increase
				print("  -> Dano Crítico aumentado em +%s%%" % (crit_damage_increase * 100))
			
			"damage_reduction":
				var reduction_percent = float(modifier_value) # Ex: 0.05 para 5%
				
				damage_reduction_multiplier *= (1.0 - reduction_percent)
				
				var total_reduction_display = (1.0 - damage_reduction_multiplier) * 100
				print("  -> Redução de Dano atualizada. Total: %s%%" % total_reduction_display)
				
			"health_regen":
				var regen_gain = float(modifier_value)
				health_regen_rate += regen_gain
				print("  -> Regeneração de Vida aumentada em +%s/s" % regen_gain)
				
			"shield":
				var shield_gain = float(modifier_value)
				max_shield += shield_gain
				current_shield += shield_gain # Ganha escudo imediatamente
				shield_changed.emit(current_shield, max_shield)
				print("  -> Escudo Máximo aumentado em +%s" % shield_gain)
				
			_:
				push_warning("Modificador passivo desconhecido: %s" % key)

func has_empty_ability_slot() -> bool:
	return active_abilities.size() < ability_slots

func has_empty_passive_slot() -> bool:
	return active_passives.size() < passive_slots

func add_xp(amount: float) -> void:
	current_xp += amount
	while current_xp >= xp_to_next_level:
		level_up()
	xp_changed.emit(current_xp, xp_to_next_level)

func level_up() -> void:
	level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level *= 1.5
	level_changed.emit(level)
	get_node("/root/GameManager").begin_level_up()

func _on_collection_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("xp_orbs"):
		# Não coleta mais. Agora, 'ativa' a atração da orbe.
		if area.has_method("set_target"):
			area.set_target(self)

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0):
	if _is_invincible or _is_dead:
		return

	# Reinicia o timer do escudo SEMPRE que tomar dano (mesmo se for 0)
	if max_shield > 0:
		shield_recharge_timer.start(shield_recharge_delay)

	# --- LÓGICA DE DEFESA (PERCENTUAL) ---
	var damage_after_reduction = amount * damage_reduction_multiplier
	var incoming_damage = roundi(damage_after_reduction)
	if incoming_damage < 1:
		incoming_damage = 1 # Garante dano mínimo de 1
	# -------------------------------------

	# --- NOVA LÓGICA DO ESCUDO ---
	var damage_to_health = incoming_damage # Dano que vai passar para a vida

	if current_shield > 0:
		var absorbed_by_shield = min(current_shield, incoming_damage)
		current_shield -= absorbed_by_shield
		damage_to_health -= absorbed_by_shield
		shield_changed.emit(current_shield, max_shield)
		print("Escudo absorveu %s de dano. Escudo restante: %s" % [absorbed_by_shield, current_shield])
	# ---------------------------

	# Se ainda houver dano após o escudo...
	if damage_to_health > 0:
		current_health -= damage_to_health
		health_changed.emit(current_health, max_health)
		_is_invincible = true # Fica invencível SÓ se tomar dano na vida

		# --- Feedback visual/sonoro SÓ se tomar dano na vida ---
		animations.play("Hurt")
		animations.modulate = flash_color
		invincibility_timer.start() # Timer de invencibilidade
		# ----------------------------------------------------

	# Knockback é aplicado mesmo se o escudo absorver tudo
	if knockback_strength > 0 and not _is_invincible: # Evita knockback duplo
		velocity = knockback_direction * knockback_strength

	# Verifica morte
	if current_health <= 0:
		_is_dead = true
		animations.play("Death")
		emit_signal("died")
		set_physics_process(false)
		collision_shape.set_deferred("disabled", true)
		print("Player Morreu!")

func _on_invincibility_timer_timeout():
	# --- MUDANÇA 7: Restaurar Cor ---
	animations.modulate = Color.WHITE
	# --------------------------------
	_is_invincible = false

# ... (Funções apply_global_cooldown_modifier e remove_global_cooldown_modifier
#      permanecem as mesmas) ...

func apply_global_cooldown_modifier(modifier: float, source_ability_id: StringName):
	for id in active_abilities:
		if id == source_ability_id:
			continue
		var ability = active_abilities[id]
		if is_instance_valid(ability):
			ability.cooldown_modifier = modifier

func remove_global_cooldown_modifier(source_ability_id: StringName):
	for id in active_abilities:
		if id == source_ability_id:
			continue
		var ability = active_abilities[id]
		if is_instance_valid(ability):
			ability.cooldown_modifier = 1.0

func get_upgrades_for_ability(ability_id: StringName) -> Array: # Agora retorna Array genérico
	# Verifica se a chave existe
	if applied_upgrades_map.has(ability_id):
		# Retorna diretamente o valor do dicionário (que é um Array)
		return applied_upgrades_map[ability_id]
	else:
		# Retorna um array genérico vazio simples
		return []

func get_calculated_damage(base_damage: int) -> int:
	# 1. Aplica o bônus de dano global
	var final_damage = base_damage * global_damage_multiplier

	# 2. Rola o dado para o crítico
	if randf() < crit_chance:
		final_damage *= crit_damage
		# (Opcional: aqui é um bom lugar para emitir um sinal
		#  de "crit_aconteceu" para mostrar um popup de dano)

	return int(final_damage)

func _on_shield_recharge_timer_timeout():
	# A recarga só começa se o timer realmente terminou
	# (e não se foi reiniciado por tomar dano)
	pass # A lógica de recarga vai para _physics_process
