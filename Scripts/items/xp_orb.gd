extends Area2D

enum State { SPAWNING, IDLE, ATTRACTED }

const NORMAL_COLOR := Color("66c6ff")
const MINIBOSS_COLOR := Color("ffd700")

var is_miniboss_orb: bool = false
var xp_amount: int = 1

var attraction_speed_min: float = 300.0
var attraction_speed_max: float = 1400.0
var attraction_acceleration: float = 1.2
var _current_attraction_speed: float = 0.0

var idle_bob_speed: float = 6.0
var idle_bob_amount_y: float = 0.15
var idle_rotate_speed: float = 3.0
var idle_rotate_amount: float = 0.15

var target: Node2D = null
var current_state: State = State.SPAWNING
var _time: float = 0.0
var _spawn_tween: Tween = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $XpOrbVisual

func _ready() -> void:
	_time = randf_range(0, TAU)
	
	if is_miniboss_orb:
		visual.color = MINIBOSS_COLOR
		scale = Vector2.ONE * 1.25
	else:
		visual.color = NORMAL_COLOR
	
	_start_spawn_animation()

func _start_spawn_animation() -> void:
	_spawn_tween = create_tween()
	var random_offset = Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	var base_scale = scale
	
	_spawn_tween.tween_property(self, "scale", Vector2(base_scale.x * 0.5, base_scale.y * 2.0), 0.1).from(Vector2.ZERO).set_trans(Tween.TRANS_SINE)
	_spawn_tween.tween_property(self, "global_position", global_position + random_offset, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_tween.parallel().tween_property(self, "rotation", randf_range(-PI, PI) * 0.5, 0.25)
	_spawn_tween.chain().tween_property(self, "scale", Vector2(base_scale.x * 1.3, base_scale.y * 0.7), 0.1)
	_spawn_tween.chain().tween_property(self, "scale", base_scale, 0.15).set_ease(Tween.EASE_OUT)
	
	_spawn_tween.tween_callback(func(): _spawn_tween = null)
	_spawn_tween.chain().tween_property(self, "rotation", 0.0, 0.05)
	
	await _spawn_tween.finished
	if current_state == State.SPAWNING:
		current_state = State.IDLE

func _physics_process(delta: float) -> void:
	_time += delta
	
	match current_state:
		
		State.IDLE:
			var bob_y = sin(_time * idle_bob_speed)
			var rot = sin(_time * idle_rotate_speed)
			
			visual.scale.y = 1.0 + (bob_y * idle_bob_amount_y)
			visual.rotation = rot * idle_rotate_amount

		State.ATTRACTED:
			if not is_instance_valid(target):
				current_state = State.IDLE
				target = null
				collision_shape.set_deferred("disabled", false)
				_current_attraction_speed = 0.0
				return

			_current_attraction_speed = lerp(_current_attraction_speed, attraction_speed_max, attraction_acceleration * delta)
			
			var direction = global_position.direction_to(target.global_position)
			global_position += direction * _current_attraction_speed * delta
			
			visual.rotation = direction.angle() + PI/2

			if global_position.distance_to(target.global_position) < 10.0:
				if target.has_method("add_xp"):
					target.add_xp(xp_amount)
				queue_free()

func set_target(new_target: Node2D) -> void:
	if current_state == State.IDLE or current_state == State.SPAWNING:
		target = new_target
		current_state = State.ATTRACTED
		collision_shape.set_deferred("disabled", true)
		
		_current_attraction_speed = attraction_speed_min
		
		if is_instance_valid(_spawn_tween):
			_spawn_tween.kill()
			_spawn_tween = null
			
		scale = Vector2.ONE * (1.25 if is_miniboss_orb else 1.0)
		visual.scale = Vector2.ONE
		rotation = 0.0
