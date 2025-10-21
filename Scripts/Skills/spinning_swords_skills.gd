extends BaseAbility

# As propriedades 'cooldown_time', 'damage_amount' e 'active_duration' são herdadas.
# Elas devem ser configuradas na cena (.tscn) pelo Inspector.
@export_category("Spinning Swords Parameters")
@export var sword_scene: PackedScene
@export var sword_count: int = 4
@export var radius: float = 80.0
@export var knockback_strength: float = 500.0
@export var rotation_speed: float = 0.7

const HIT_COOLDOWN: float = 0.5
const SWORD_ROTATION_OFFSET: float = PI / 2

@onready var pivot: Node2D = $Pivot

# Dicionário para rastrear inimigos em cooldown de acerto.
var _enemies_on_hit_cooldown: Dictionary = {}

# Em vez de _ready, usamos _ability_ready para a configuração.
func _ability_ready() -> void:
	pivot.visible = false
	_generate_swords()
	
	# Conecta à nova sinalização da BaseAbility para saber quando desativar.
	on_deactivated.connect(_on_attack_finished)

# Esta função é chamada pela BaseAbility quando a habilidade é ativada.
func _on_activate(_params: Dictionary) -> void:
	# Lógica para INICIAR o efeito visual/funcional da habilidade.
	pivot.visible = true
	_set_swords_monitoring_enabled(true)
	_enemies_on_hit_cooldown.clear()

# Processa a rotação apenas se a habilidade estiver na sua fase ativa.
func _process(delta: float):
	if is_active(): # Usa a nova função is_active() da BaseAbility
		pivot.rotation += rotation_speed * delta

# Esta função é chamada pelo sinal on_deactivated da BaseAbility.
func _on_attack_finished():
	# Lógica para PARAR o efeito visual/funcional da habilidade.
	pivot.visible = false
	_set_swords_monitoring_enabled(false)
	_enemies_on_hit_cooldown.clear()

# O restante das funções permanece o mesmo...
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
		push_error("A cena da espada (sword_scene) não está definida!")
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
