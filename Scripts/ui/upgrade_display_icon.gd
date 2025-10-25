extends Control

const UPGRADE_TOOLTIP_SCENE = preload("res://Scenes/ui/upgrade_tooltip.tscn")

@export var rarity_rect: NodePath

@onready var ability_icon_rect: TextureRect = $AbilityIcon

var _upgrade_data: AbilityUpgrade

const RARITY_COLORS = {
	AbilityUpgrade.Rarity.COMMON: Color("9d9d9d"),
	AbilityUpgrade.Rarity.UNCOMMON: Color("43a047"),
	AbilityUpgrade.Rarity.RARE: Color("1e88e5"),
	AbilityUpgrade.Rarity.EPIC: Color("8e24aa"),
	AbilityUpgrade.Rarity.LEGENDARY: Color("f4511e")
}

var _hover_tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_upgrade_data(upgrade: AbilityUpgrade):
	if not upgrade:
		return
	_upgrade_data = upgrade

	var rarity_color = RARITY_COLORS.get(upgrade.rarity, Color.WHITE)

	var rect_node = get_node_or_null(rarity_rect) as TextureRect
	if rect_node:
		rect_node.modulate = rarity_color
	else:
		printerr("RarityRect node not found at path: ", rarity_rect)

	if upgrade.icon:
		ability_icon_rect.texture = upgrade.icon
		ability_icon_rect.show()
	else:
		ability_icon_rect.texture = null
		ability_icon_rect.hide()

func _make_custom_tooltip(_for_text: String) -> Object:
	if not _upgrade_data:
		return null 

	var tooltip_instance = UPGRADE_TOOLTIP_SCENE.instantiate()

	var label = tooltip_instance.find_child("TooltipLabel") as RichTextLabel
	if label:
		var bbcode = "[b]%s[/b]\n\n%s" % [_upgrade_data.ability_name, _upgrade_data.description]
		if _upgrade_data.icon:
			bbcode = "[img width=32]%s[/img] [b]%s[/b]\n\n%s" % [_upgrade_data.icon.resource_path, _upgrade_data.ability_name, _upgrade_data.description]
		
		label.text = bbcode

	return tooltip_instance

func _on_mouse_entered() -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	
	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)

func _on_mouse_exited() -> void:
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()
	
	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
