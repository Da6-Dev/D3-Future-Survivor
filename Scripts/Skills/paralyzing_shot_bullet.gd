# Scripts/Skills/paralyzing_shot_bullet.gd
extends Area2D

var damage: int = 1
var speed: float = 600.0
var knockback_strength: float = 100.0
var pierce_count: int = 0
var stun_duration: float = 1.0 # Duração da paralisia

var _direction: Vector2 = Vector2.RIGHT
var _pierced_enemies: Array[Node2D] = []
var player: Node = null

func _ready() -> void:
	# --- CORREÇÃO AQUI ---
	# Trocamos o sinal de 'body_entered' para 'area_entered'
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

func set_direction(dir: Vector2):
	_direction = dir.normalized()
	rotation = _direction.angle()

# --- CORREÇÃO AQUI ---
# A função foi renomeada para '_on_area_entered' e o parâmetro mudou para 'area: Area2D'
func _on_area_entered(area: Area2D):
	# O 'area' é o Hurtbox. 'area.get_owner()' é o Inimigo.
	var target = area.get_owner()
	
	if target.is_in_group("enemies") and not target in _pierced_enemies:
		if target.has_method("take_damage"):
			var final_damage = damage
			if is_instance_valid(player):
				final_damage = player.get_calculated_damage(damage)
			# Chamamos 'take_damage' diretamente no inimigo (target)
			target.take_damage(final_damage, _direction, knockback_strength)
			
			# --- APLICA A PARALISIA ---
			if target.has_method("apply_stun"):
				target.apply_stun(stun_duration)
				
			_pierced_enemies.append(target)
		
		if pierce_count <= 0:
			queue_free()
		else:
			pierce_count -= 1

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
