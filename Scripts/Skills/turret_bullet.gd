# Scripts/Skills/turret_bullet.gd
extends Area2D

var damage: int = 1 # Valor BASE
var speed: float = 700.0
var knockback_strength: float = 150.0 # Valor BASE
var max_travel_distance: float = 500.0

var _direction: Vector2 = Vector2.RIGHT
var _distance_traveled: float = 0.0
var player: Node = null

# --- NOVA FUNÇÃO CHAMADA PELA TORRETA ---
func initialize_with_modifiers(mods: Dictionary):
	# Aplica modificadores que foram passados
	if mods.has("damage_amount"):
		damage += mods["damage_amount"]
	if mods.has("knockback_strength"):
		knockback_strength += mods["knockback_strength"]
	# Adicione outros modificadores de bala aqui (ex: pierce_count)
	#print("Modificadores aplicados na Bala: ", mods)
# -----------------------------------------

func _ready() -> void:
	area_entered.connect(_on_area_entered)

# ... (_physics_process, set_direction, _on_area_entered,
#      _on_visible_on_screen_notifier_2d_screen_exited
#      permanecem iguais) ...
func _physics_process(delta: float) -> void:
	var distance_to_move = speed * delta
	global_position += _direction * distance_to_move
	_distance_traveled += distance_to_move
	if _distance_traveled >= max_travel_distance:
		queue_free()

func set_direction(dir: Vector2):
	_direction = dir.normalized()
	rotation = _direction.angle()

func _on_area_entered(area: Area2D):
	var target = area.get_owner()
	if target.is_in_group("enemies"):
		if target.has_method("take_damage"):
			var final_damage = damage
			if is_instance_valid(player):
				final_damage = player.get_calculated_damage(damage)
			target.take_damage(final_damage, _direction, knockback_strength)
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
