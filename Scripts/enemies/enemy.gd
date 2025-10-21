# Scripts/enemies/enemy.gd
extends CharacterBody2D

# --- Sinais ---
signal died(enemy_node: CharacterBody2D)

# --- Constantes ---
const PLAYER_GROUP: String = "player"

# --- Parâmetros de Inimigo (Exportáveis para o editor) ---
@export_group("Stats")
@export var max_health: int = 5:
	set(value):
		max_health = maxi(1, value)
		if current_health > max_health:
			current_health = max_health

@export var speed: float = 120.0
@export var acceleration: float = 800.0
@export var xp_amount: int = 1
@export var damage: int = 10
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

# --- Referências de Nós ---
@onready var sprite: Sprite2D = $EnemyVisual
@onready var collision_shape: CollisionShape2D = $PhysicsCollision
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var player_search_timer: Timer = $PlayerSearchTimer
@onready var attack_cooldown_timer: Timer = $MeleeAttackArea/Cooldown
@onready var melee_attack_area: Area2D = $MeleeAttackArea
@onready var crown_icon: Sprite2D = $CrownIcon # Referência ao sprite da coroa
# --- NOVO TIMER REFERENCIADO ---
@onready var stun_timer: Timer = $StunTimer

var _can_attack: bool = true
var is_miniboss: bool = false # Flag para saber se é miniboss
var XpOrb: PackedScene = preload("res://Scenes/items/xp_orb.tscn")

enum EnemyState {
	IDLE,
	CHASE,
	KNOCKBACK,
	STUNNED, # <-- NOVO ESTADO
	DEAD
}

var player: CharacterBody2D = null
var current_health: int
var current_state: EnemyState = EnemyState.IDLE:
	set(value):
		if current_state != value:
			_exit_state(current_state)
			current_state = value
			_enter_state(current_state)

func _ready():
	current_health = max_health
	knockback_timer.wait_time = knockback_duration
	knockback_timer.one_shot = true
	knockback_timer.timeout.connect(on_knockback_timer_timeout)
	
	# --- NOVA CONEXÃO ---
	stun_timer.one_shot = true
	stun_timer.timeout.connect(_on_stun_timer_timeout)
	
	player_search_timer.wait_time = player_search_interval
	player_search_timer.timeout.connect(_find_player)
	player_search_timer.start()
	attack_cooldown_timer.wait_time = attack_cooldown
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	_find_player()
	transition_to_state(EnemyState.IDLE)

func _physics_process(delta: float):
	# --- LÓGICA MODIFICADA AQUI ---
	# Não processa movimento normal ou ataque se estiver paralisado
	if current_state == EnemyState.STUNNED:
		velocity = Vector2.ZERO # Garante que ele pare
		move_and_slide()
		return # Pula o resto da função

	# Se não estiver paralisado, continua normal
	_process_state(delta)
	move_and_slide()
	
	# --- NOVA LÓGICA DE ATAQUE ---
	# Se estamos perto o suficiente E podemos atacar..
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
		EnemyState.IDLE:      _update_idle_state(delta)
		EnemyState.CHASE:     _update_chase_state(delta)
		EnemyState.KNOCKBACK: _update_knockback_state(delta)
		EnemyState.STUNNED:   _update_stunned_state(delta) # <-- NOVO
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
		
		# --- NOVO ---
		EnemyState.STUNNED:
			velocity = Vector2.ZERO # Para o inimigo
			if sprite:
				sprite.modulate = Color.YELLOW # Feedback visual de paralisia
		
		EnemyState.DEAD:
			velocity = Vector2.ZERO
			set_physics_process(false)
			if sprite:
				sprite.modulate = death_tint_color
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
			emit_signal("died", self)
			var orb = XpOrb.instantiate()
			orb.xp_amount = xp_amount
			orb.is_miniboss_orb = self.is_miniboss # Informa à orbe se ela é especial
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
			
		# --- NOVO ---
		EnemyState.STUNNED:
			if sprite:
				sprite.modulate = Color.WHITE # Restaura a cor
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

# --- NOVO ---
func _update_stunned_state(_delta: float):
	# O movimento é parado em _physics_process
	pass

func _update_dead_state(_delta: float):
	pass

func set_health(value: int):
	current_health = clampi(value, 0, max_health)
	if current_health <= 0 and current_state != EnemyState.DEAD:
		transition_to_state(EnemyState.DEAD)

func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO, knockback_strength: float = 0.0):
	# Não pode tomar dano/knockback se estiver morto ou paralisado
	if current_state == EnemyState.DEAD or current_state == EnemyState.STUNNED:
		return
		
	set_health(current_health - amount)
	
	if current_state != EnemyState.DEAD and knockback_strength > 0:
		velocity = knockback_direction * knockback_strength
		transition_to_state(EnemyState.KNOCKBACK)

# --- NOVA FUNÇÃO ---
# Esta é a função que o projétil irá chamar
func apply_stun(duration: float):
	# Não pode ser paralisado se estiver morto
	if current_state == EnemyState.DEAD:
		return
		
	# Se já estiver em knockback ou paralisado, reinicia o timer
	stun_timer.wait_time = duration
	stun_timer.start()
	
	# Transiciona para o estado de paralisia
	transition_to_state(EnemyState.STUNNED)

# --- NOVA FUNÇÃO ---
func _on_stun_timer_timeout():
	# Só volta ao normal se AINDA estiver paralisado
	if current_state == EnemyState.STUNNED:
		transition_to_state(EnemyState.CHASE if is_instance_valid(player) else EnemyState.IDLE)


func on_knockback_timer_timeout():
	if current_state == EnemyState.KNOCKBACK:
		transition_to_state(EnemyState.CHASE if is_instance_valid(player) else EnemyState.IDLE)

func _find_player():
	if is_queued_for_deletion():
		return
	var potential_player = get_tree().get_first_node_in_group(PLAYER_GROUP)
	if is_instance_valid(potential_player):
		player = potential_player
		if current_state == EnemyState.IDLE:
			transition_to_state(EnemyState.CHASE)
	else:
		player = null
		if current_state == EnemyState.CHASE:
			transition_to_state(EnemyState.IDLE)
		# push_warning("Enemy: Não foi possível encontrar o nó do jogador no grupo '%s'." % PLAYER_GROUP)
# (Comentei o warning para não poluir o log)

func _on_hurtbox_area_entered(area: Area2D):
	# Verifica se a área que entrou tem um método 'take_damage'
	# (Isso é uma simplificação, idealmente você checaria o grupo da área)
	if area.has_method("get_damage_payload"):
		var payload = area.get_damage_payload()

		# Chama a função take_damage que já existe
		take_damage(
			payload.get("amount", 1),
			payload.get("direction", Vector2.ZERO),
			payload.get("knockback", 0.0)
		)

		# Se a área for um projétil que se destrói (como uma bala),
		# podemos pedir para ela se destruir.
		if area.has_method("hit_target"):
			area.hit_target()


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
	
	# 1. Procura por todos os "Hurtboxes" que estão dentro da sua área de ataque
	var hurtboxes = melee_attack_area.get_overlapping_areas()
	
	for hurtbox in hurtboxes:
		# 2. Verifica se o "dono" do hurtbox é o jogador
		# (Usamos get_owner() para pegar o nó 'Player' de dentro do 'Hurtbox')
		var target = hurtbox.get_owner()
		
		# 3. Se for o jogador e ele puder tomar dano...
		if target.is_in_group("player") and target.has_method("take_damage"):
			
			# 4. Pega o "payload" do inimigo (de si mesmo)
			var payload = get_damage_payload()
			
			# 5. Chama a função 'take_damage' DIRETAMENTE no jogador
			target.take_damage(
				payload.get("amount", 1),
				payload.get("direction", Vector2.ZERO),
				payload.get("knockback", 0.0)
			)
			
			# (Como é um ataque corpo-a-corpo, não quebramos o loop,
			#  pois só deve haver um jogador)

func setup_enemy(p_is_miniboss: bool = false, health_multiplier: float = 1.0, scale_multiplier: float = 1.0, xp_multiplier: float = 1.0):
	is_miniboss = p_is_miniboss

	max_health = int(max_health * health_multiplier)
	current_health = max_health
	xp_amount = int(xp_amount * xp_multiplier)
	scale *= scale_multiplier

	if is_miniboss:
		# --- CORREÇÃO AQUI ---
		# Tenta pegar o nó CrownIcon diretamente AQUI,
		# em vez de depender da variável @onready que ainda pode ser null.
		var crown_node: Sprite2D = get_node_or_null("CrownIcon")

		if is_instance_valid(crown_node): # Verifica se o nó foi encontrado
			crown_node.visible = true
			# (Lógica da animação, se houver)
		else:
			# Se ainda assim não encontrar, o problema é na cena .tscn
			push_warning("Nó CrownIcon não encontrado DENTRO de setup_enemy!")
		# --------------------

		if sprite:
			sprite.self_modulate = Color(1.0, 0.8, 0.8)
