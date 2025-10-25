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
		add_child(ability_instance)
		ability_instance.set_player_reference(self)
		ability_instance.total_attack_speed_multiplier += current_stats.global_attack_speed_bonus
		var id = ability_instance.ability_id
		if id == &"":
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
		last_direction = Vector2.RIGHT

func apply_upgrade(upgrade: AbilityUpgrade):
	var target_id = upgrade.target_ability_id
	if not applied_upgrades_map.has(target_id):
		applied_upgrades_map[target_id] = []
	applied_upgrades_map[target_id].append(upgrade)

	if upgrade.type == AbilityUpgrade.UpgradeType.UNLOCK_NEW_ABILITY:
		var scene_to_load = upgrade.new_ability_scene
		if scene_to_load is PackedScene:
			var ability_instance: BaseAbility = scene_to_load.instantiate()
			add_child(ability_instance)
			ability_instance.set_player_reference(self)
			ability_instance.total_attack_speed_multiplier += current_stats.global_attack_speed_bonus
			var id = ability_instance.ability_id
			active_abilities[id] = ability_instance
			emit_signal("ability_added", ability_instance)

	elif upgrade.type == AbilityUpgrade.UpgradeType.UPGRADE_EXISTING_ABILITY:
		var target_ability = active_abilities.get(upgrade.target_ability_id)
		if is_instance_valid(target_ability):
			var needs_special_handling = false
			var needs_timer_update = false

			for key in upgrade.modifiers:
				var modifier_value = upgrade.modifiers[key]

				if key == "attack_speed_multiplier":
					var current_mult = target_ability.get("total_attack_speed_multiplier")
					target_ability.set("total_attack_speed_multiplier", current_mult + modifier_value)
					needs_timer_update = true
				elif not key in target_ability:
					continue 
				else:
					var current_value = target_ability.get(key)
					target_ability.set(key, current_value + modifier_value)

				if key == "sword_count" or key == "radius" or key == "drone_count":
					needs_special_handling = true

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
					
	elif upgrade.type == AbilityUpgrade.UpgradeType.APPLY_PASSIVE_STAT:
		var stat_id = upgrade.passive_stat_id
		
		if not active_passives.has(stat_id):
			if has_empty_passive_slot():
				active_passives[stat_id] = [upgrade]
				_apply_passive_stat(upgrade)
		else:
			active_passives[stat_id].append(upgrade)
			_apply_passive_stat(upgrade)
	
func _apply_passive_stat(upgrade: AbilityUpgrade):
	for key in upgrade.modifiers:
		var modifier_value = upgrade.modifiers[key]
		match key:
			"max_health":
				var health_gain = int(modifier_value)
				current_stats.max_health += health_gain
				current_health += health_gain
				health_changed.emit(current_health, current_stats.max_health)

			"attack_speed":
				var speed_increase_percent = float(modifier_value)
				current_stats.global_attack_speed_bonus += speed_increase_percent
				for ability in active_abilities.values():
					ability.total_attack_speed_multiplier += speed_increase_percent
					if ability.has_method("update_timers"):
						ability.update_timers()
						
			"damage_reduction":
				var reduction_percent = float(modifier_value)
				current_stats.damage_reduction_multiplier *= (1.0 - reduction_percent)
				
			"shield":
				var shield_gain = float(modifier_value)
				current_stats.max_shield += shield_gain
				current_shield += shield_gain 
				shield_changed.emit(current_shield, current_stats.max_shield)

			"health_regen":
				var regen_gain = float(modifier_value)
				current_stats.health_regen_rate += regen_gain
				
			"global_damage":
				var damage_gain_percent = float(modifier_value)
				current_stats.global_damage_multiplier += damage_gain_percent
				
			_:
				var handled_keys = ["health_regen", "health_regen_rate", "global_damage"]
				if (key in current_stats) and (not key in handled_keys):
					var current_value = current_stats.get(key)
					current_stats.set(key, current_value + modifier_value)

func has_empty_ability_slot() -> bool:
	return active_abilities.size() < current_stats.ability_slots

func has_empty_passive_slot() -> bool:
	return active_passives.size() < current_stats.passive_slots

func add_xp(amount: float) -> void:
	collect_sound.play()
	current_xp += amount
	while current_xp >= xp_to_next_level:
		level_up()
	xp_changed.emit(current_xp, xp_to_next_level)

func level_up() -> void:
	level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = round(xp_to_next_level * 1.25)
	level_changed.emit(level)
	get_node("/root/GameManager").begin_level_up()

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
	var incoming_damage = damage_after_reduction
	if incoming_damage < 1:
		incoming_damage = 1

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
		health_changed.emit(current_health, current_stats.max_health)
		_is_invincible = true

		animations.play("Hurt")
		animations.modulate = flash_color
		invincibility_timer.start()

	if current_health <= 0 and not _is_dead:
		_is_dead = true
		animations.play("Death")
		emit_signal("game_over", _time_elapsed, current_stats, applied_upgrades_map, active_passives, level, current_xp, xp_to_next_level)
		set_physics_process(false)
		collision_shape.set_deferred("disabled", true)

func _on_invincibility_timer_timeout():
	animations.modulate = Color.WHITE
	_is_invincible = false

func _exit_tree() -> void:
	EntityManager.unregister_player()

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

func get_upgrades_for_ability(ability_id: StringName) -> Array:
	if applied_upgrades_map.has(ability_id):
		return applied_upgrades_map[ability_id]
	else:
		return []

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
	pass
