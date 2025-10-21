extends Node2D

@onready var visual: Node2D = $Visual

var bob_frequency: float = 3.0
var bob_amplitude: float = 4.0
var max_squash_amount: float = 0.2
var squash_speed_cap: float = 500.0

func _ready():
	if not visual:
		return

func update_visual_animations(velocity: Vector2, time: float, index: int, delta: float):
	if not is_instance_valid(visual):
		return

	visual.position.y = sin(time * bob_frequency + index * PI) * bob_amplitude
	visual.position.x = 0

	var speed = velocity.length()
	
	var squash_y = remap(speed, 0.0, squash_speed_cap, 1.0, 1.0 - max_squash_amount)
	var stretch_x = remap(speed, 0.0, squash_speed_cap, 1.0, 1.0 + max_squash_amount)

	var target_scale = Vector2(stretch_x, squash_y)
	
	visual.scale = visual.scale.lerp(target_scale, delta * 10.0)
