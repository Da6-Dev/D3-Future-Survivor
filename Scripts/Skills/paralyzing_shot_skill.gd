# Scripts/Skills/paralyzing_shot_skill.gd
extends BaseAbility

@export_category("Paralyzing Shot")
@export var bullet_scene: PackedScene
@export var stun_duration: float = 1.0
@export var knockback_strength: float = 100.0
@export var pierce_count: int = 0
# (damage_amount e cooldown_time são herdados e configurados na cena)

func _ability_ready() -> void:
	# --- CONFIGURAÇÃO CHAVE ---a
	requires_aiming = true    
	# Deixe o valor do inspetor (da cena .tscn) ser usado
	active_duration = 0.0
	# -------------------------

func _on_activate(params: Dictionary) -> void:
	if not bullet_scene:
		printerr("Cena do projétil (bullet_scene) não definida no Tiro Paralisante!")
		return
	
	var base_angle = params.get("attack_angle", 0.0)
	var direction = Vector2.RIGHT.rotated(base_angle)

	var bullet_instance: Area2D = bullet_scene.instantiate()
	
	# Adiciona à raiz da cena para que não gire com o jogador
	get_tree().root.add_child(bullet_instance)
	bullet_instance.global_position = global_position
	bullet_instance.player = player # Passa a referência do player
	
	# Passa as propriedades da habilidade para o projétil
	bullet_instance.set_direction(direction)
	bullet_instance.damage = self.damage_amount
	bullet_instance.knockback_strength = self.knockback_strength
	bullet_instance.stun_duration = self.stun_duration
	bullet_instance.pierce_count = self.pierce_count
