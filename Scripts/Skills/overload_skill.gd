extends BaseAbility

@export_category("Overload Explosion")
@export var explosion_radius: float = 150.0
@export var explosion_knockback: float = 600.0

@export_category("Overload Buff")
@export var cooldown_reduction_percent: float = 0.3

var camera: Camera2D
var original_camera_zoom: Vector2
@onready var sfx_explosion : AudioStreamPlayer = $SfxDownsampled
@onready var explosion_collider : Area2D = $Area2D
@onready var explosion_effect : GPUParticles2D = $Explosion

func _ability_ready() -> void:
	on_deactivated.connect(_on_buff_finished)
	if is_instance_valid(player) and player.has_node("PlayerCamera"):
		camera = player.get_node("PlayerCamera")
		original_camera_zoom = camera.zoom

func _on_activate(_params: Dictionary) -> void:
	EntityManager.trigger_shake(70.0, 0.65, 125.0)
	
	sfx_explosion.play()
	_create_explosion_effect()
	_apply_explosion_knockback()
	_apply_player_buff()

func _apply_explosion_knockback():
	var bodies = explosion_collider.get_overlapping_bodies()
	
	for a in range(bodies.size()):
		if bodies[a].is_in_group("enemies"):
			var knockback_direction = (bodies[a].global_position - global_position).normalized()
			var final_damage_payload = player.get_calculated_damage(damage_amount)
			bodies[a].take_damage(final_damage_payload, knockback_direction, 1350)
	
func _apply_player_buff():
	if is_instance_valid(player) and player.has_method("apply_global_cooldown_modifier"):
		player.apply_global_cooldown_modifier(1.0 - cooldown_reduction_percent, ability_id)

	if is_instance_valid(camera):
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(camera, "zoom", original_camera_zoom * 0.95, 0.2)

func _on_buff_finished():
	if is_instance_valid(player) and player.has_method("remove_global_cooldown_modifier"):
		player.remove_global_cooldown_modifier(ability_id)
		
	if is_instance_valid(camera):
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(camera, "zoom", original_camera_zoom, 0.5)

func _create_explosion_effect():
	explosion_effect.restart(true)
	explosion_effect.emitting = true
