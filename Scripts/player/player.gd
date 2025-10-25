extends CharacterBody2D

signal xp_changed(current_xp: float, xp_to_next_level: float)
signal level_changed(new_level: int)
signal health_changed(current_health: float, max_health: float)
signal game_over(time_survived: float, final_stats: PlayerStats, final_upgrades: Dictionary, final_passives: Dictionary, final_level: int, final_xp: float, final_xp_needed: float)
signal ability_added(ability: BaseAbility)
signal shield_changed(current_shield: float, max_shield: float)

var base_stats: PlayerStats
var current_stats: PlayerStats

@export_group("Damage Feedback")
@export var invincibility_duration: float = 0.5
@export var flash_color: Color = Color.RED

@onready var animations: AnimatedSprite2D = $PlayerAnimations
@onready var collision_shape: CollisionShape2D = $PhysicalCollision
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var shield_recharge_timer: Timer = $ShieldRechargeTimer
@onready var player_hurt : AudioStreamPlayer = $HitHurt
@onready var collect_sound : AudioStreamPlayer = $CollectSound

var active_abilities: Dictionary[StringName, BaseAbility] = {}
var active_passives: Dictionary = {}

var _health_regen_accumulator: float = 0.0
var current_shield: float = 0.0
var applied_upgrades_map: Dictionary = {}
var last_direction: Vector2 = Vector2.RIGHT
var _is_invincible: bool = false
var current_health: float
var current_xp: float = 0.0
var xp_to_next_level: float = 5.0
var level: int = 1
var _is_dead: bool = false
var _time_elapsed: float = 0.0
var _is_initialized: bool = false

func _ready() -> void:
	EntityManager.register_player(self)
	if GameSession.chosen_class:
		_apply_class_data(GameSession.chosen_class)
	else:
		var fallback_class = load("res://Player/Classes/guerreiro.tres")
		if fallback_class:
			_apply_class_data(fallback_class)
		else:
			push_error("Classe padrão não encontrada!")
			base_stats = PlayerStats.new()
			current_stats = base_stats.duplicate()
			current_health = current_stats.max_health


	update_last_direction_from_input()
	invincibility_timer.wait_time = invincibility_duration
	invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)
	shield_recharge_timer.timeout.connect(_on_shield_recharge_timer_timeout)

	health_changed.emit(current_health, current_stats.max_health)
	xp_changed.emit(current_xp, xp_to_next_level)
	level_changed.emit(level)
	shield_changed.emit(current_shield, current_stats.max_shield)
	_is_initialized = true

func _physics_process(delta: float) -> void:
	_time_elapsed += delta
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if current_stats.health_regen_rate > 0.0 and current_health < current_stats.max_health:
		_health_regen_accumulator += current_stats.health_regen_rate * delta

		if _health_regen_accumulator >= 1.0:
			var heal_amount = floori(_health_regen_accumulator)
			_health_regen_accumulator -= heal_amount
			current_health += heal_amount
			current_health = min(current_health, current_stats.max_health)
			health_changed.emit(current_health, current_stats.max_health)
	
	if current_stats.max_shield > 0.0 and current_shield < current_stats.max_shield and shield_recharge_timer.is_stopped():
		current_shield += current_stats.shield_recharge_rate * delta
		current_shield = min(current_shield, current_stats.max_shield)
		shield_changed.emit(current_shield, current_stats.max_shield)
	
	if _is_invincible:
		velocity = velocity.move_toward(Vector2.ZERO, current_stats.speed / 2)
	else:
		handle_movement()
	
	move_and_slide()
	_update_animations()

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

func _update_animations() -> void:
	if animations.animation == "Hurt" and animations.is_playing():
		return

	if velocity.length_squared() > 0:
		animations.play("Run")
	else:
		animations.play("Idle")

	if last_direction.x != 0:
		animations.flip_h = (last_direction.x < 0)

func _find_closest_enemy() -> CharacterBody2D:
	return EntityManager.get_closest_enemy(global_position)

func _apply_class_data(class_data: PlayerClass):
	if class_data.base_stats is PlayerStats:
		self.base_stats = class_data.base_stats
		self.current_stats = base_stats.duplicate()
	else:
		self.base_stats = PlayerStats.new()
		self.current_stats = PlayerStats.new()

	self.current_health = self.current_stats.max_health

	if class_data.starting_ability_scene is PackedScene:
		var ability_instance: BaseAbility = class_data.starting_ability_scene.instantiate()
		
		# --- CORREÇÃO DE ORDEM (classe inicial) ---
		ability_instance.set_player_reference(self) # Define a referência ANTES
		add_child(ability_instance) # Adiciona DEPOIS
		
		ability_instance.total_attack_speed_multiplier += current_stats.global_attack_speed_bonus
		var id = ability_instance.ability_id
		if id == &"":
			push_warning("Habilidade inicial da classe %s não tem ability_id definido!" % class_data.name_class)
			return
			
		active_abilities[id] = ability_instance
		emit_signal("ability_added", ability_instance)

func handle_movement() -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length() > 0:
		last_direction = input_direction.normalized()
	velocity = input_direction * current_stats.speed

func update_last_direction_from_input() -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length() > 0:
		last_direction = input_direction.normalized()
	else:
		# Mantém a última direção válida se não houver input
		pass # Ou poderia definir um padrão como Vector2.RIGHT se preferir

func apply_upgrade(upgrade: AbilityUpgrade):
	var target_id = upgrade.target_ability_id
	if not applied_upgrades_map.has(target_id):
		applied_upgrades_map[target_id] = []
	applied_upgrades_map[target_id].append(upgrade)

	if upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY:
		var scene_to_load = upgrade.new_ability_scene
		if scene_to_load is PackedScene:
			var ability_instance: BaseAbility = scene_to_load.instantiate()
			if not ability_instance:
				printerr("Falha ao instanciar a cena da habilidade: ", scene_to_load.resource_path)
				return

			# --- CORREÇÃO DE ORDEM (upgrade) ---
			# 1. Definir a referência do player PRIMEIRO
			ability_instance.set_player_reference(self)
			
			# 2. Aplicar bônus de velocidade de ataque
			ability_instance.total_attack_speed_multiplier += current_stats.global_attack_speed_bonus
			
			# 3. Adicionar à árvore de cena (isso chama _ready)
			add_child(ability_instance)
			
			var id = ability_instance.ability_id
			if id == &"":
				push_warning("Habilidade desbloqueada (%s) não tem ability_id definido!" % upgrade.id)
				# Decide se remove ou deixa, dependendo da sua lógica
				# ability_instance.queue_free() # Exemplo: remover se não tiver ID
				return
				
			active_abilities[id] = ability_instance
			emit_signal("ability_added", ability_instance)
			
			# Aplica upgrades existentes para esta nova habilidade, se houver
			_reapply_upgrades_for_ability(id)


	elif upgrade.type == AbilityUpgrade.UpgradeType.UPGRADE_EXISTING_ABILITY:
		var target_ability = active_abilities.get(upgrade.target_ability_id)
		if is_instance_valid(target_ability):
			_apply_modifier_to_ability(target_ability, upgrade)
					
	elif upgrade.type == AbilityUpgrade.UpgradeType.APPLY_PASSIVE_STAT:
		var stat_id = upgrade.passive_stat_id
		
		if not active_passives.has(stat_id):
			if has_empty_passive_slot():
				active_passives[stat_id] = [upgrade]
				_apply_passive_stat_modifier(upgrade)
			else:
				push_warning("Tentativa de adicionar passiva '%s' sem slot disponível." % stat_id)
		else:
			active_passives[stat_id].append(upgrade)
			_apply_passive_stat_modifier(upgrade)

# Função auxiliar para aplicar modificadores a uma habilidade existente
func _apply_modifier_to_ability(target_ability: BaseAbility, upgrade: AbilityUpgrade):
	var needs_special_handling = false
	var needs_timer_update = false

	for key in upgrade.modifiers:
		var modifier_value = upgrade.modifiers[key]

		if key == "attack_speed_multiplier":
			var current_mult = target_ability.get("total_attack_speed_multiplier")
			target_ability.set("total_attack_speed_multiplier", current_mult + modifier_value)
			needs_timer_update = true
		elif not key in target_ability:
			printerr("Upgrade '%s' tenta modificar propriedade '%s' inexistente na habilidade '%s'." % [upgrade.id, key, target_ability.ability_id])
			continue 
		else:
			var current_value = target_ability.get(key)
			# Lógica especial para 'hit_cooldown' (redução percentual)
			if key == "hit_cooldown":
				# Garantir que o modificador seja interpretado como redução percentual
				# Ex: 0.1 significa 10% mais rápido (multiplica por 0.9)
				target_ability.set(key, current_value * (1.0 - modifier_value))
			# Lógica especial para 'cooldown_reduction_percent' (buff overload)
			elif key == "cooldown_reduction_percent":
				target_ability.set(key, current_value + modifier_value) # Soma percentuais
			# Lógica padrão (adição)
			else:
				# Tratar diferentes tipos
				if typeof(current_value) == TYPE_FLOAT:
					target_ability.set(key, float(current_value) + float(modifier_value))
				elif typeof(current_value) == TYPE_INT:
					target_ability.set(key, int(current_value) + int(modifier_value))
				else:
					printerr("Tipo não suportado '%s' para modificador '%s' no upgrade '%s'" % [typeof(current_value), key, upgrade.id])

		# Chamadas de atualização específicas
		if key == "damage_amount":
			if target_ability.has_method("update_damage"):
				target_ability.update_damage()

		if key == "sword_count" or key == "radius" or key == "drone_count":
			needs_special_handling = true
		
		if key == "hit_cooldown":
			if target_ability.has_method("update_hit_cooldown"):
				target_ability.update_hit_cooldown()
			
	if needs_special_handling:
		if target_ability.has_method("regenerate_swords"):
			target_ability.regenerate_swords()
		if target_ability.has_method("update_radius"):
			target_ability.update_radius()
		if target_ability.has_method("regenerate_drones"):
			target_ability.regenerate_drones()

	if needs_timer_update:
		if target_ability.has_method("update_timers"):
			target_ability.update_timers()

# Função auxiliar para reaplicar upgrades a uma habilidade recém-adicionada
func _reapply_upgrades_for_ability(ability_id: StringName):
	if applied_upgrades_map.has(ability_id):
		var target_ability = active_abilities.get(ability_id)
		if is_instance_valid(target_ability):
			var upgrades_to_apply = applied_upgrades_map[ability_id]
			for upgrade in upgrades_to_apply:
				# Só aplica se for upgrade existente (não o de unlock)
				if upgrade.type == AbilityUpgrade.UpgradeType.UPGRADE_EXISTING_ABILITY:
					_apply_modifier_to_ability(target_ability, upgrade)

# Função auxiliar para aplicar modificadores de status passivos
func _apply_passive_stat_modifier(upgrade: AbilityUpgrade):
	var health_before = current_stats.max_health
	var shield_before = current_stats.max_shield

	for key in upgrade.modifiers:
		var modifier_value = upgrade.modifiers[key]
		
		# --- Lógica de aplicação dos status passivos ---
		match key:
			"max_health":
				current_stats.max_health += float(modifier_value)
			"speed":
				current_stats.speed += float(modifier_value)
			"damage_reduction_multiplier":
				# Redução é multiplicativa (10% = multiplicar por 0.9)
				current_stats.damage_reduction_multiplier *= (1.0 - float(modifier_value))
			"health_regen_rate":
				current_stats.health_regen_rate += float(modifier_value)
			"global_damage_multiplier":
				current_stats.global_damage_multiplier += float(modifier_value)
			"global_attack_speed_bonus":
				var speed_increase_percent = float(modifier_value)
				current_stats.global_attack_speed_bonus += speed_increase_percent
				# Aplicar bônus global a todas as habilidades existentes
				for ability in active_abilities.values():
					if is_instance_valid(ability):
						# Apenas adiciona o bônus do upgrade atual
						ability.total_attack_speed_multiplier += speed_increase_percent 
						if ability.has_method("update_timers"):
							ability.update_timers()
			"crit_chance":
				current_stats.crit_chance += float(modifier_value)
			"crit_damage":
				current_stats.crit_damage += float(modifier_value)
			"max_shield":
				current_stats.max_shield += float(modifier_value)
			"shield_recharge_delay":
				current_stats.shield_recharge_delay *= (1.0 - float(modifier_value)) # Redução percentual
				current_stats.shield_recharge_delay = max(0.1, current_stats.shield_recharge_delay) # Evitar delay zero/negativo
			"shield_recharge_rate":
				current_stats.shield_recharge_rate += float(modifier_value)
			"ability_slots":
				current_stats.ability_slots += int(modifier_value)
			"passive_slots":
				current_stats.passive_slots += int(modifier_value)
			_:
				printerr("Status passivo desconhecido '%s' no upgrade '%s'" % [key, upgrade.id])

	# Atualizar vida/escudo atual e emitir sinais se max mudou
	var health_diff = current_stats.max_health - health_before
	if health_diff > 0:
		current_health += health_diff
		health_changed.emit(current_health, current_stats.max_health)
	
	var shield_diff = current_stats.max_shield - shield_before
	if shield_diff > 0:
		current_shield += shield_diff
		shield_changed.emit(current_shield, current_stats.max_shield)


func has_empty_ability_slot() -> bool:
	return active_abilities.size() < current_stats.ability_slots

func has_empty_passive_slot() -> bool:
	# Considera o número de *tipos* de passivas, não o número total de upgrades passivos
	return active_passives.size() < current_stats.passive_slots

func add_xp(amount: float) -> void:
	collect_sound.play()
	if _is_dead: return # Não ganha XP se morto
	current_xp += amount
	while current_xp >= xp_to_next_level:
		level_up()
	xp_changed.emit(current_xp, xp_to_next_level)

func level_up() -> void:
	if not _is_initialized or _is_dead: # Não upa se não inicializado ou morto
		# Se não inicializado, acumula XP para o primeiro level up real
		if not _is_initialized:
			current_xp += xp_to_next_level 
		return
		
	level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = round(xp_to_next_level * 1.25)
	level_changed.emit(level)
	# Garante que GameManager exista antes de chamar
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.begin_level_up()
	else:
		printerr("GameManager não encontrado para iniciar o level up!")


func _on_collection_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("xp_orbs"):
		if area.has_method("set_target"):
			area.set_target(self)

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0):
	if _is_invincible or _is_dead:
		return

	if current_stats.max_shield > 0:
		shield_recharge_timer.start(current_stats.shield_recharge_delay)

	var damage_after_reduction = amount * current_stats.damage_reduction_multiplier
	# Garante que o dano seja pelo menos 1, a menos que a redução seja 100% ou mais
	var incoming_damage = max(1.0, damage_after_reduction) if current_stats.damage_reduction_multiplier < 1.0 else 0.0

	var damage_to_health = incoming_damage

	if current_shield > 0:
		var absorbed_by_shield = min(current_shield, incoming_damage)
		current_shield -= absorbed_by_shield
		damage_to_health -= absorbed_by_shield
		shield_changed.emit(current_shield, current_stats.max_shield)
	
	if knockback_strength > 0:
		velocity = knockback_direction * knockback_strength

	if damage_to_health > 0:
		player_hurt.play()
		EntityManager.trigger_shake(15.0, 0.2, 25.0)
		current_health -= damage_to_health
		current_health = max(0, current_health) # Evitar vida negativa
		health_changed.emit(current_health, current_stats.max_health)
		_is_invincible = true

		animations.play("Hurt")
		# Usar tween para o flash para não interferir com a animação "Hurt"
		var tween = create_tween().set_parallel()
		tween.tween_property(animations, "modulate", flash_color, 0.1)
		tween.chain().tween_property(animations, "modulate", Color.WHITE, 0.1).set_delay(invincibility_duration - 0.1)

		invincibility_timer.start()

	if current_health <= 0 and not _is_dead:
		_is_dead = true
		animations.play("Death") # Assume que existe uma animação de morte
		await animations.animation_finished # Espera a animação de morte terminar (opcional)
		emit_signal("game_over", _time_elapsed, current_stats, applied_upgrades_map, active_passives, level, current_xp, xp_to_next_level)
		# Não desabilitar physics process imediatamente se tiver animação de morte
		# set_physics_process(false) 
		collision_shape.set_deferred("disabled", true)


func _on_invincibility_timer_timeout():
	# Modulate é controlado pelo tween agora
	# animations.modulate = Color.WHITE 
	_is_invincible = false

func _exit_tree() -> void:
	EntityManager.unregister_player()

func apply_global_cooldown_modifier(modifier: float, source_ability_id: StringName):
	for id in active_abilities:
		if id == source_ability_id:
			continue
		var ability = active_abilities.get(id)
		if is_instance_valid(ability):
			ability.cooldown_modifier = modifier

func remove_global_cooldown_modifier(source_ability_id: StringName):
	for id in active_abilities:
		if id == source_ability_id:
			continue
		var ability = active_abilities.get(id)
		if is_instance_valid(ability):
			ability.cooldown_modifier = 1.0

func get_upgrades_for_ability(ability_id: StringName) -> Array:
	return applied_upgrades_map.get(ability_id, [])

func get_calculated_damage(base_damage: float) -> Dictionary:
	var final_damage = base_damage * current_stats.global_damage_multiplier
	var is_crit = false 
	
	if randf() < current_stats.crit_chance:
		final_damage *= current_stats.crit_damage
		is_crit = true 
		
	return {
		"amount": final_damage,
		"is_critical": is_crit
	}

func _on_shield_recharge_timer_timeout():
	# A lógica de recarga está no _physics_process
	pass
