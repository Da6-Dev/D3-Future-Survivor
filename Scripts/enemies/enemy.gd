extends CharacterBody2D

signal died(enemy_node: CharacterBody2D)

const PLAYER_GROUP: String = "player"

@export_group("Stats")
@export var max_health: float = 5.0:
	set(value):
		max_health = maxf(1.0, value)
		if current_health > max_health:
			current_health = max_health
@export var speed: float = 120.0
@export var acceleration: float = 800.0
@export var xp_amount: int = 1
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var knockback_strength: float = 750.0

@export_group("Movement AI")
@export var stopping_distance: float = 15.0
@export var player_search_interval: float = 1.0

@export_group("Knockback")
@export var knockback_duration: float = 0.25
@export var knockback_friction: float = 1200.0

@export_group("Visuals & Effects")
@export var damage_tint_color: Color = Color.RED
@export var death_tint_color: Color = Color.GRAY
@export var death_delay: float = 0.5

@onready var sprite: Sprite2D = $EnemyVisual
@onready var collision_shape: CollisionShape2D = $PhysicsCollision
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var attack_cooldown_timer: Timer = $MeleeAttackArea/Cooldown
@onready var melee_attack_area: Area2D = $MeleeAttackArea
@onready var crown_icon: Sprite2D = $CrownIcon
@onready var stun_timer: Timer = $StunTimer
@onready var hit_sound : AudioStreamPlayer = $HitSound

var _can_attack: bool = true
var is_miniboss: bool = false
var XpOrb: PackedScene = preload("res://Scenes/items/xp_orb.tscn")
const DamageLabelScene: PackedScene = preload("res://Scenes/ui/damage_label.tscn")

var _target_scale: Vector2 = Vector2.ONE

enum EnemyState {
	IDLE,
	CHASE,
	KNOCKBACK,
	STUNNED,
	DEAD
}

var player: CharacterBody2D = null
var current_health: float
var current_state: EnemyState = EnemyState.IDLE:
	set(value):
		if current_state != value:
			_exit_state(current_state)
			current_state = value
			_enter_state(current_state)


func _ready():
	
	var T : Tween = get_tree().create_tween()
	
	T.tween_property(self,"scale", _target_scale, 1.0).from(_target_scale * 0.3).set_trans(Tween.TRANS_CUBIC)
	
	EntityManager.register_enemy(self)
	current_health = max_health
	knockback_timer.wait_time = knockback_duration
	knockback_timer.one_shot = true
	knockback_timer.timeout.connect(on_knockback_timer_timeout)
	
	stun_timer.one_shot = true
	stun_timer.timeout.connect(_on_stun_timer_timeout)
	
	attack_cooldown_timer.wait_time = attack_cooldown
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	player = EntityManager.get_player()
	transition_to_state(EnemyState.IDLE)

func _physics_process(delta: float):
	if current_state == EnemyState.STUNNED:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_process_state(delta)
	move_and_slide()
	
	if is_instance_valid(player) and global_position.distance_to(player.global_position) < stopping_distance + 10 and _can_attack:
		_attack()

func deal_damage_to_player(player_node):
	if player_node.has_method("take_damage"):
		var knockback_direction = (player_node.global_position - global_position).normalized()
		player_node.take_damage(damage, knockback_direction, knockback_strength)
		_can_attack = false
		attack_cooldown_timer.start()

func _on_attack_cooldown_timeout():
	_can_attack = true

func _process_state(delta: float):
	match current_state:
		EnemyState.IDLE:     _update_idle_state(delta)
		EnemyState.CHASE:     _update_chase_state(delta)
		EnemyState.KNOCKBACK: _update_knockback_state(delta)
		EnemyState.STUNNED:   _update_stunned_state(delta)
		EnemyState.DEAD:      _update_dead_state(delta)

func _enter_state(new_state: EnemyState):
	match new_state:
		EnemyState.IDLE:
			velocity = Vector2.ZERO
		EnemyState.CHASE:
			pass
		EnemyState.KNOCKBACK:
			if sprite:
				sprite.modulate = damage_tint_color
			knockback_timer.start()
			# --- CORREÇÃO 2 (Desativar Colisão) ---
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
		
		EnemyState.STUNNED:
			velocity = Vector2.ZERO
			if sprite:
				sprite.modulate = Color.YELLOW
		
		EnemyState.DEAD:
			EntityManager.unregister_enemy(self)
			
			var T : Tween = get_tree().create_tween()
			T.set_parallel(true)
			T.tween_property(self,"scale",Vector2(0,0),0.55).from(_target_scale * 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)
			T.tween_property(self,"modulate",Color(1,1,1,0),0.55).from(Color(1,1,1,1)).set_trans(Tween.TRANS_LINEAR)
			
			velocity = Vector2.ZERO
			set_physics_process(false)
			if sprite:
				sprite.modulate = death_tint_color
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
			emit_signal("died", self)
			var orb = XpOrb.instantiate()
			orb.xp_amount = xp_amount
			orb.is_miniboss_orb = self.is_miniboss
			get_parent().call_deferred("add_child", orb)
			orb.global_position = global_position
			get_tree().create_timer(death_delay, false).timeout.connect(queue_free)

func _exit_state(old_state: EnemyState):
	match old_state:
		EnemyState.IDLE:
			pass
		EnemyState.CHASE:
			pass
		EnemyState.KNOCKBACK:
			if sprite:
				sprite.modulate = Color.WHITE
			knockback_timer.stop()
			# --- CORREÇÃO 2 (Reativar Colisão) ---
			if collision_shape:
				collision_shape.set_deferred("disabled", false)
			
		EnemyState.STUNNED:
			if sprite:
				sprite.modulate = Color.WHITE
			stun_timer.stop()
			
		EnemyState.DEAD:
			pass

func transition_to_state(new_state: EnemyState):
	self.current_state = new_state

func _update_idle_state(delta: float):
	if is_instance_valid(player) and global_position.distance_to(player.global_position) > stopping_distance:
		transition_to_state(EnemyState.CHASE)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)

func _update_chase_state(delta: float):
	if not is_instance_valid(player):
		transition_to_state(EnemyState.IDLE)
		return
	var target_velocity = Vector2.ZERO
	if global_position.distance_to(player.global_position) > stopping_distance:
		var direction = (player.global_position - global_position).normalized()
		target_velocity = direction * speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

func _update_knockback_state(delta: float):
	velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)

func _update_stunned_state(_delta: float):
	pass

func _update_dead_state(_delta: float):
	pass

func set_health(value: float):
	current_health = clampf(value, 0.0, max_health)
	if current_health <= 0 and current_state != EnemyState.DEAD:
		transition_to_state(EnemyState.DEAD)

func take_damage(damage_payload: Dictionary, knockback_direction: Vector2 = Vector2.ZERO, incoming_knockback_strength: float = 0.0):
	if typeof(damage_payload) != TYPE_DICTIONARY:
		push_error("take_damage recebeu um payload inválido! Tipo: %s" % typeof(damage_payload))
		return

	# --- CORREÇÃO 1 (Dano em Stun) ---
	# Removido 'or current_state == EnemyState.STUNNED'
	if current_state == EnemyState.DEAD:
		return

	var amount = damage_payload.get("amount", 1.0)
	var is_crit = damage_payload.get("is_critical", false)
	
	var label_instance = DamageLabelScene.instantiate()
	get_tree().current_scene.call_deferred("add_child", label_instance)
	var start_pos = global_position + Vector2(0, -30)
	label_instance.setup(amount, is_crit, start_pos)
	
	if is_crit:
		EntityManager.trigger_shake(10.0, 0.1, 30.0)
	set_health(current_health - amount)
	hit_sound.play()
	
	# Não aplicar knockback se já estiver em um estado de "paralisia"
	if current_state != EnemyState.DEAD and current_state != EnemyState.STUNNED and incoming_knockback_strength > 0:
		velocity = knockback_direction * incoming_knockback_strength
		transition_to_state(EnemyState.KNOCKBACK)

func apply_stun(duration: float):
	if current_state == EnemyState.DEAD:
		return
		
	stun_timer.wait_time = duration
	stun_timer.start()
	
	transition_to_state(EnemyState.STUNNED)

func _on_stun_timer_timeout():
	if current_state == EnemyState.STUNNED:
		transition_to_state(EnemyState.CHASE if is_instance_valid(player) else EnemyState.IDLE)

func on_knockback_timer_timeout():
	if current_state == EnemyState.KNOCKBACK:
		transition_to_state(EnemyState.CHASE if is_instance_valid(player) else EnemyState.IDLE)

func get_damage_payload() -> Dictionary:
	var knockback_direction = (player.global_position - global_position).normalized()
	return {
		"amount": damage,
		"direction": knockback_direction,
		"knockback": knockback_strength
	}
	
func _attack():
	_can_attack = false
	attack_cooldown_timer.start()
	
	var hurtboxes = melee_attack_area.get_overlapping_areas()
	
	for hurtbox in hurtboxes:
		var target = hurtbox.get_owner()
		
		if target.is_in_group("player") and target.has_method("take_damage"):
			var payload = get_damage_payload()
			
			target.take_damage(
				payload.get("amount", 1.0),
				payload.get("direction", Vector2.ZERO),
				payload.get("knockback", 0.0)
			)

func setup_enemy(p_is_miniboss: bool = false, health_multiplier: float = 1.0, scale_multiplier: float = 1.0, xp_multiplier: float = 1.0):
	is_miniboss = p_is_miniboss

	max_health = int(max_health * health_multiplier)
	current_health = max_health
	xp_amount = int(xp_amount * xp_multiplier)
	
	_target_scale = scale * scale_multiplier

	if is_miniboss:
		var crown_node: Sprite2D = get_node_or_null("CrownIcon")

		if is_instance_valid(crown_node):
			crown_node.visible = true
		
		if sprite:
			sprite.self_modulate = Color(1.0, 0.8, 0.8)
