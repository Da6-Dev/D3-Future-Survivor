extends Control

# --- Referências de Nós ---
# Pegamos referências aos botões para podermos conectar seus sinais.
@onready var play_button: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/PlayButton
@onready var settings_button: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/SettingsButton
@onready var exit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/ExitButton
@onready var settings_menu: CanvasLayer = $SettingsMenu

func _ready() -> void:
	# Conecta o sinal "pressed" de cada botão a uma função correspondente.
	# Isso garante que quando um botão for clicado, a função certa será chamada.
	play_button.pressed.connect(_on_play_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)


# Chamada quando o botão "Play" é pressionado.
func _on_play_button_pressed() -> void:
	# MUDANÇA AQUI
	var err = get_tree().change_scene_to_file("res://Scenes/main/choose_class_menu.tscn")
	if err != OK:
		printerr("Não foi possível carregar a cena de seleção de classe. Verifique o caminho!")

# Chamada quando o botão "Settings" é pressionado.
func _on_settings_button_pressed() -> void:
	# AQUI ESTÁ A MUDANÇA!
	settings_menu.open_menu()

# Chamada quando o botão "Exit" é pressionado.
func _on_exit_button_pressed() -> void:
	# Esta função fecha a aplicação.
	get_tree().quit()
