extends BaseAbility

@export_category("Spinning Swords Parameters")
@export var sword_scene: PackedScene
@export var sword_count: int = 4
@export var radius: float = 80.0
@export var knockback_strength: float = 500.0
@export var rotation_speed: float = 0.7

const HIT_COOLDOWN: float = 0.5
const SWORD_ROTATION_OFFSET: float = PI / 2

@onready var pivot: Node2D = $Pivot

var _enemies_on_hit_cooldown: Dictionary = {}

func _ability_ready() -> void:
	pivot.visible = false
	_generate_swords()
	on_deactivated.connect(_on_attack_finished)

func _on_activate(_params: Dictionary) -> void:
	pivot.visible = true
	_set_swords_monitoring_enabled(true)
	_enemies_on_hit_cooldown.clear()

func _process(delta: float):
	if is_active():
		pivot.rotation += rotation_speed * delta

func _on_attack_finished():
	pivot.visible = false
	_set_swords_monitoring_enabled(false)
	_enemies_on_hit_cooldown.clear()

func _on_sword_hit(body: Node, sword_node: Area2D):
	if _enemies_on_hit_cooldown.has(body):
		return

	if body.has_method("take_damage"):
		var knockback_direction: Vector2 = (body.global_position - sword_node.global_position).normalized()
		var final_damage = player.get_calculated_damage(damage_amount) 
		body.take_damage(final_damage, knockback_direction, knockback_strength)
		
		var hit_timer: SceneTreeTimer = get_tree().create_timer(HIT_COOLDOWN)
		_enemies_on_hit_cooldown[body] = hit_timer
		await hit_timer.timeout
		
		if _enemies_on_hit_cooldown.has(body):
			_enemies_on_hit_cooldown.erase(body)

func regenerate_swords():
	for sword in pivot.get_children():
		sword.queue_free()
	_generate_swords()

func _generate_swords():
	if not sword_scene:
		return
		
	for i in range(sword_count):
		var angle = i * (TAU / sword_count)
		var sword_instance: Area2D = sword_scene.instantiate()
		sword_instance.sword_hit.connect(_on_sword_hit)
		sword_instance.position = Vector2(radius, 0).rotated(angle)
		sword_instance.rotation = angle + SWORD_ROTATION_OFFSET
		pivot.add_child(sword_instance)
		
	_set_swords_monitoring_enabled(false)

func _set_swords_monitoring_enabled(is_enabled: bool):
	for sword in pivot.get_children():
		if sword is Area2D:
			sword.monitoring = is_enabled
