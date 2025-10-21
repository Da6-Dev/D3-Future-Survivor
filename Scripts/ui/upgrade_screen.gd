extends CanvasLayer

signal upgrade_selected(upgrade: AbilityUpgrade)

const UpgradeCardScene = preload("res://Scenes/ui/upgrade_card.tscn")
@onready var card_container: HBoxContainer = $ColorRect/MarginContainer/VBoxContainer/CardContainer

func show_options(upgrades: Array[AbilityUpgrade]) -> void:
	for child in card_container.get_children():
		child.queue_free()
		
	for upgrade_data in upgrades:
		var card_instance = UpgradeCardScene.instantiate()
		card_container.add_child(card_instance)
		card_instance.display_upgrade(upgrade_data)
		card_instance.chosen.connect(_on_upgrade_chosen)
		
	self.show()

func _on_upgrade_chosen(chosen_upgrade: AbilityUpgrade) -> void:
	self.hide()
	emit_signal("upgrade_selected", chosen_upgrade)
