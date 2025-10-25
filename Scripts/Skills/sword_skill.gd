extends BaseAbility

@export_category("Sword Skill Parameters")
@export var knockback_strength: float = 150.0
@export var radius: float = 1.0 # Valor base é 1.0 (escala de 100%)
var shatter_chance: float = 0.0
var shatter_damage_percent: float = 0.0

@onready var visual_area: Polygon2D = $SwordArea/AttackAreaVisual
@onready var collision_shape_2d: CollisionPolygon2D = $SwordArea/AttackAreaCollision
@onready var attack_area: Area2D = $SwordArea

func _ability_ready() -> void:
	visual_area.visible = false
	collision_shape_2d.disabled = true

	attack_area.area_entered.connect(_on_area_entered)
	on_deactivated.connect(_on_attack_finished)

func _on_activate(params: Dictionary) -> void:
	var attack_angle = params.get("attack_angle", 0.0)
	self.rotation = attack_angle

	visual_area.visible = true
	collision_shape_2d.disabled = false

func _on_attack_finished() -> void:
	visual_area.visible = false
	collision_shape_2d.disabled = true

func _on_area_entered(area: Area2D) -> void:
	if not is_instance_valid(player):
		return

	var target = area.get_owner()

	if target.has_method("take_damage"):
		var knockback_direction = (target.global_position - global_position).normalized()
		var final_damage_payload = player.get_calculated_damage(damage_amount)
		
		# Aplica o dano primeiro
		target.take_damage(final_damage_payload, knockback_direction, knockback_strength)
		
		# --- CORREÇÃO AQUI ---
		# Verificamos a vida do 'target' (o inimigo), não da 'area' (o hurtbox)
		if target.current_health <= 0:
			if randf() < shatter_chance:
				# Usamos a posição do 'target' para a explosão
				_create_explosion(target.global_position)
		
func update_radius():
	# Esta função é chamada pelo player.gd quando
	# um upgrade de "radius" é aplicado.
	if $SwordArea:
		$SwordArea.scale = Vector2(radius, radius)

# --- FUNÇÃO COMPLETADA ---
# Cria uma explosão em tempo real usando código
func _create_explosion(position: Vector2):
	# 1. Cria a área de explosão
	var explosion_area = Area2D.new()
	explosion_area.global_position = position
	
	# 2. Configura a colisão (para acertar a camada 16, onde estão os hurtboxes)
	explosion_area.collision_layer = 32 # Camada da espada
	explosion_area.collision_mask = 16  # Máscara do hurtbox do inimigo
	
	# 3. Cria a forma da explosão (um círculo de raio 60)
	var explosion_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 60.0 # Você pode ajustar este valor
	explosion_shape.shape = circle_shape
	
	# 4. Adiciona os nós à cena
	explosion_area.add_child(explosion_shape)
	get_tree().current_scene.add_child(explosion_area)
	
	# 5. Calcula o dano da explosão
	var explosion_base_damage = damage_amount * shatter_damage_percent
	var explosion_payload = player.get_calculated_damage(explosion_base_damage)
	
	# 6. Espera um frame para a física detectar as colisões
	await get_tree().physics_frame
	
	# 7. Aplica o dano
	var hurtboxes = explosion_area.get_overlapping_areas()
	for hurtbox in hurtboxes:
		var target = hurtbox.get_owner()
		if is_instance_valid(target) and target.has_method("take_damage"):
			# Explosão não aplica knockback, apenas dano
			target.take_damage(explosion_payload, Vector2.ZERO, 0.0)
	
	# 8. Limpa a área de explosão da cena
	explosion_area.queue_free()
