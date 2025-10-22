extends Area2D
class_name BaseProjectile

var damage: float = 1.0
var speed: float = 800.0
var knockback_strength: float = 100.0
var pierce_count: int = 0

var _direction: Vector2 = Vector2.RIGHT
var pierced_enemies: Array[Node2D] = []
var player: Node = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	var notifier = find_child("VisibleOnScreenNotifier2D")
	if notifier:
		notifier.screen_exited.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()
	rotation = _direction.angle()

func _on_area_entered(_area: Area2D) -> void:
	pass

func _apply_damage(target: Node2D) -> void:
	if target.has_method("take_damage"):
		var final_damage_payload = _get_final_damage_payload()
		target.take_damage(final_damage_payload, _direction, knockback_strength)

func _get_final_damage_payload() -> Dictionary:
	if is_instance_valid(player) and player.has_method("get_calculated_damage"):
		return player.get_calculated_damage(damage)
	return {"amount": damage, "is_critical": false}

func _handle_pierce() -> void:
	if pierce_count <= 0:
		queue_free()
	else:
		pierce_count -= 1
