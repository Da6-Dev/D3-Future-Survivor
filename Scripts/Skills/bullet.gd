extends Area2D

var damage: int = 1
var speed: float = 800.0
var knockback_strength: float = 100.0
var pierce_count: int = 0

var _direction: Vector2 = Vector2.RIGHT
var _pierced_enemies: Array[Node2D] = []
var player: Node = null

func _ready() -> void:
	# --- MUDANÇA 1: Mudar de body_entered para area_entered ---
	area_entered.connect(_on_area_entered)   # Conecta o novo sinal

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

func set_direction(dir: Vector2):
	_direction = dir.normalized()
	rotation = _direction.angle()

# --- MUDANÇA 2: Criar a função get_damage_payload ---
# Esta é a função que o Hurtbox do inimigo irá chamar
func get_damage_payload() -> Dictionary:
	var final_damage = damage
	if is_instance_valid(player):
		final_damage = player.get_calculated_damage(damage)
	return {
		"amount": final_damage,
		"direction": _direction,
		"knockback": knockback_strength
	}

# --- MUDANÇA 3: Renomear a função e mudar a lógica ---
func _on_area_entered(area: Area2D): 
	# 'area' é o Hurtbox do inimigo
	var target = area.get_owner()
	
	# Esta função agora SÓ registra o inimigo para evitar acertos duplicados.
	# O dano, o 'hit_target()' e a destruição são gerenciados pelo 'enemy.gd'.
	if target.is_in_group("enemies") and not target in _pierced_enemies:
		_pierced_enemies.append(target)

# --- MUDANÇA 4: Esta função é chamada pelo Hurtbox do inimigo ---
func hit_target():
	if pierce_count <= 0:
		queue_free()
	else:
		pierce_count -= 1

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
