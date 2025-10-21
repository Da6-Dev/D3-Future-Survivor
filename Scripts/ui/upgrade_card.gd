extends PanelContainer

# Sinal emitido quando o jogador escolhe esta carta.
# Ele enviará os dados do upgrade que ele representa.
signal chosen(upgrade: AbilityUpgrade)

@onready var ability_name_label: Label = $VBoxContainer/AbilityNameLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var choose_button: Button = $VBoxContainer/ChooseButton

var _upgrade_data: AbilityUpgrade

func _ready() -> void:
	# Conecta o sinal "pressed" do botão a uma função neste script.
	choose_button.pressed.connect(_on_choose_button_pressed)

# Função pública para popular a carta com os dados de um upgrade.
func display_upgrade(upgrade: AbilityUpgrade) -> void:
	_upgrade_data = upgrade
	ability_name_label.text = upgrade.ability_name
	description_label.text = upgrade.description
	
	# Bônus: Mudar a cor da carta com base na raridade (opcional)
	var rarity_colors = {
		AbilityUpgrade.Rarity.COMMON: Color.WHITE,
		AbilityUpgrade.Rarity.UNCOMMON: Color.GREEN,
		AbilityUpgrade.Rarity.RARE: Color.BLUE,
		AbilityUpgrade.Rarity.EPIC: Color.PURPLE,
		AbilityUpgrade.Rarity.LEGENDARY: Color.ORANGE
	}
	self_modulate = rarity_colors.get(upgrade.rarity, Color.WHITE)


func _on_choose_button_pressed() -> void:
	# Quando o botão é pressionado, emite o sinal "chosen" com os dados do upgrade.
	emit_signal("chosen", _upgrade_data)
