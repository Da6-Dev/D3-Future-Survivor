extends BaseAbility

@export_category("Overload Explosion")
@export var explosion_radius: float = 150.0
@export var explosion_knockback: float = 600.0

@export_category("Overload Buff")
@export var cooldown_reduction_percent: float = 0.3 # 30% de redução

# active_duration é usado como a duração do buff

var camera: Camera2D
var original_camera_zoom: Vector2

func _ability_ready() -> void:
	on_deactivated.connect(_on_buff_finished)
	# Busca a câmera de forma segura
	if is_instance_valid(player) and player.has_node("PlayerCamera"):
		camera = player.get_node("PlayerCamera")
		original_camera_zoom = camera.zoom

func _on_activate(_params: Dictionary) -> void:
	_create_explosion_effect()
	_apply_explosion_knockback()
	_apply_player_buff()

func _apply_explosion_knockback():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) <= explosion_radius:
			if enemy.has_method("take_damage"):
				var direction = (enemy.global_position - global_position).normalized()
				var final_damage = player.get_calculated_damage(damage_amount)
				enemy.take_damage(final_damage, direction, explosion_knockback)

func _apply_player_buff():
	if is_instance_valid(player) and player.has_method("apply_global_cooldown_modifier"):
		player.apply_global_cooldown_modifier(1.0 - cooldown_reduction_percent, ability_id)

	# Efeito de câmera: Zoom out rápido
	if is_instance_valid(camera):
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(camera, "zoom", original_camera_zoom * 0.95, 0.2) # Zoom out 5%

func _on_buff_finished():
	if is_instance_valid(player) and player.has_method("remove_global_cooldown_modifier"):
		player.remove_global_cooldown_modifier(ability_id)
		
	# Efeito de câmera: Retorno suave ao zoom original
	if is_instance_valid(camera):
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(camera, "zoom", original_camera_zoom, 0.5)

func _create_explosion_effect():
	var tween = create_tween()
	var visual_ring = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32
		points.append(Vector2(cos(angle), sin(angle)) * explosion_radius)
	
	visual_ring.polygon = points
	visual_ring.color = Color(1.0, 0.8, 0.2, 0.8)
	add_child(visual_ring)
	
	tween.tween_property(visual_ring, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUINT)
	tween.tween_callback(visual_ring.queue_free)
