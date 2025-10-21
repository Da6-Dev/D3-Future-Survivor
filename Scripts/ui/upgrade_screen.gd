extends CanvasLayer

# V Verifique se esta linha está exatamente assim e no topo do script V
signal upgrade_selected(upgrade: AbilityUpgrade)

const UpgradeCardScene = preload("res://Scenes/ui/upgrade_card.tscn")
@onready var card_container: HBoxContainer = $ColorRect/MarginContainer/VBoxContainer/CardContainer


func show_options(upgrades: Array[AbilityUpgrade]) -> void:
	# Limpa quaisquer cartas antigas antes de adicionar novas.
	for child in card_container.get_children():
		child.queue_free()
		
	# Para cada um dos 3 upgrades sorteados...
	for upgrade_data in upgrades:
		# ...cria uma nova instância da carta.
		var card_instance = UpgradeCardScene.instantiate()
		# Adiciona a carta ao contêiner.
		card_container.add_child(card_instance)
		# Popula a carta com os dados do upgrade.
		card_instance.display_upgrade(upgrade_data)
		# Conecta o sinal "chosen" da carta a uma função nesta tela.
		card_instance.chosen.connect(_on_upgrade_chosen)
		
	# Mostra a tela de upgrade.
	self.show()


# Chamada quando o jogador clica no botão "Escolher" de qualquer carta.
func _on_upgrade_chosen(chosen_upgrade: AbilityUpgrade) -> void:
	# Esconde a tela.
	self.hide()
	# Emite o sinal para avisar o GameManager
	emit_signal("upgrade_selected", chosen_upgrade)
