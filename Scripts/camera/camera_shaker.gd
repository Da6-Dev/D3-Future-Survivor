extends Node

var _shake_strength: float = 0.0
var _shake_timer: Timer
var _shake_frequency: float = 20.0
var _noise: FastNoiseLite
var _noise_y_seed: int = 12345

var _camera: Camera2D

func _ready() -> void:
	_camera = get_parent() as Camera2D
	if not _camera:
		printerr("CameraShaker não é filho de uma Camera2D!")
		queue_free()
		return
		
	_shake_timer = Timer.new()
	_shake_timer.one_shot = true
	_shake_timer.timeout.connect(_on_shake_timer_timeout)
	add_child(_shake_timer)
	
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.01
	
func _physics_process(_delta: float) -> void:
	if _shake_strength <= 0.0 or not is_instance_valid(_camera):
		return

	var time = Time.get_ticks_msec() * 0.01 * _shake_frequency
	
	var noise_x = _noise.get_noise_2d(time, _noise.seed)
	var noise_y = _noise.get_noise_2d(time, _noise_y_seed)
	
	_camera.offset.x = noise_x * _shake_strength
	_camera.offset.y = noise_y * _shake_strength

func shake(strength: float, duration: float, frequency: float = 20.0) -> void:
	_shake_strength = strength
	_shake_frequency = frequency
	_shake_timer.wait_time = duration
	_noise_y_seed = randi()
	_shake_timer.start()

func _on_shake_timer_timeout() -> void:
	_shake_strength = 0.0
	if is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
