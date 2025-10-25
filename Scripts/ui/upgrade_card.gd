extends PanelContainer

signal chosen(upgrade: AbilityUpgrade)
signal mouse_entered_card(card: PanelContainer)
signal mouse_exited_card()

@export var _upgrade_data: AbilityUpgrade

@onready var ability_name_label: Label = $VBoxContainer/AbilityNameLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var ability_icon_rect: TextureRect = $VBoxContainer/UpgradeIcon
@onready var separator_2: HSeparator = $VBoxContainer/HSeparator2
@onready var separator_3: HSeparator = $VBoxContainer/HSeparator3
@onready var shine_color : Color = material.get_shader_parameter("shine_color")

var idle_tween: Tween

func _ready() -> void:
	if material is ShaderMaterial:
		material = material.duplicate()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	play_appear_animation()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var tween = create_tween().set_trans(Tween.TRANS_SINE)
			tween.tween_property(self, "scale", Vector2.ONE, 0.1)
			
			var pulse_tween = create_tween()
			var bright_shine = Color(1.0, 1.0, 1.0, 0.8)
			pulse_tween.tween_property(material, "shader_parameter/shine_color", bright_shine, 0.1)
			pulse_tween.tween_property(material, "shader_parameter/shine_color", shine_color, 0.2).set_delay(0.1)

		elif event.is_released():
			emit_signal("chosen", _upgrade_data)
			get_viewport().set_input_as_handled()

func display_upgrade(upgrade: AbilityUpgrade) -> void:
	_upgrade_data = upgrade
	ability_name_label.text = upgrade.ability_name
	description_label.text = upgrade.description
	if upgrade.icon:
		ability_icon_rect.texture = upgrade.icon
		ability_icon_rect.show()
	else:
		ability_icon_rect.texture = null
		ability_icon_rect.hide()
	
	var rarity_colors = {
		AbilityUpgrade.Rarity.COMMON: Color.WHITE, 
		AbilityUpgrade.Rarity.UNCOMMON: Color.GREEN,
		AbilityUpgrade.Rarity.RARE: Color.BLUE, 
		AbilityUpgrade.Rarity.EPIC: Color.PURPLE,
		AbilityUpgrade.Rarity.LEGENDARY: Color.ORANGE
	}
	var base_color = rarity_colors.get(upgrade.rarity, Color.WHITE)
	
	if material is ShaderMaterial:
		material.set_shader_parameter("base_color", base_color)
	if is_instance_valid(separator_2):
		separator_2.modulate = base_color
	if is_instance_valid(separator_3):
		separator_3.modulate = base_color
	if is_instance_valid(ability_icon_rect):
		ability_icon_rect.modulate = base_color


func play_idle_animation() -> void:
	if idle_tween:
		idle_tween.kill()
	idle_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	idle_tween.tween_property(self, "position:y", -5, 1.5).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(self, "position:y", 0, 1.5).set_ease(Tween.EASE_IN_OUT)

func play_appear_animation() -> void:
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	position.y = 50
	pivot_offset = size / 2

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.4)
	tween.parallel().tween_property(self, "position:y", 0, 0.4)

	await tween.finished
	play_idle_animation()

func _on_mouse_entered() -> void:
	if idle_tween:
		idle_tween.kill()

	emit_signal("mouse_entered_card", self)
	
	var hover_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	hover_tween.parallel().tween_property(self, "position:y", -20, 0.2)
	hover_tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.2)
	
	var flash_tween = create_tween()
	var shine_width = material.get_shader_parameter("shine_width")
	flash_tween.tween_property(material, "shader_parameter/shine_progress", 2.0 + shine_width, 0.4).from(-shine_width)

func _on_mouse_exited() -> void:
	emit_signal("mouse_exited_card")
	
	var return_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	return_tween.parallel().tween_property(self, "position:y", 0, 0.2)
	return_tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	var shine_width = material.get_shader_parameter("shine_width")
	material.set_shader_parameter("shine_progress", -shine_width)
	
	await return_tween.finished
	
	play_idle_animation()
