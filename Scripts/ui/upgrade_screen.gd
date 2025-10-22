extends CanvasLayer

signal upgrade_selected(upgrade: AbilityUpgrade)

const UpgradeCardScene = preload("res://Scenes/ui/upgrade_card.tscn")
@onready var card_container: HBoxContainer = $ColorRect/MarginContainer/VBoxContainer/CardContainer
@onready var background: ColorRect = $ColorRect

var _selection_made := false

func show_options(upgrades: Array[AbilityUpgrade]) -> void:
	_selection_made = false
	
	for child in card_container.get_children():
		child.queue_free()
		
	background.modulate.a = 0.0
	self.show()
	
	var screen_tween = create_tween()
	screen_tween.tween_property(background, "modulate:a", 1.0, 0.2)
	await screen_tween.finished
		
	for i in range(upgrades.size()):
		var upgrade_data = upgrades[i]
		var card_instance = UpgradeCardScene.instantiate()
		card_container.add_child(card_instance)
		card_instance.display_upgrade(upgrade_data)
		
		card_instance.chosen.connect(_on_upgrade_chosen)
		card_instance.mouse_entered_card.connect(_on_card_hovered)
		card_instance.mouse_exited_card.connect(_on_card_unhovered)
		
		card_instance.play_appear_animation()
		await get_tree().create_timer(0.1).timeout

func _on_card_hovered(hovered_card: PanelContainer) -> void:
	if _selection_made: return
	
	for card in card_container.get_children():
		if card != hovered_card:
			var tween = create_tween().set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(card, "scale", Vector2(0.95, 0.95), 0.2)
			tween.parallel().tween_property(card, "modulate", Color(0.7, 0.7, 0.7), 0.2)

func _on_card_unhovered() -> void:
	if _selection_made: return
	
	for card in card_container.get_children():
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.2)
		tween.parallel().tween_property(card, "modulate", Color.WHITE, 0.2)

func _on_upgrade_chosen(chosen_upgrade: AbilityUpgrade) -> void:
	if _selection_made: return
	_selection_made = true
	
	var chosen_card_node = null
	for card in card_container.get_children():
		if card._upgrade_data == chosen_upgrade:
			chosen_card_node = card
			break

	var exit_tween = create_tween().set_parallel()
	
	for card in card_container.get_children():
		if card == chosen_card_node:
			exit_tween.tween_property(card, "scale", Vector2(1.2, 1.2), 0.3).set_delay(0.1)
			exit_tween.tween_property(card, "modulate:a", 0.0, 0.4)
		else:
			exit_tween.tween_property(card, "modulate:a", 0.0, 0.2)

	await exit_tween.finished
	
	self.hide()
	emit_signal("upgrade_selected", chosen_upgrade)
