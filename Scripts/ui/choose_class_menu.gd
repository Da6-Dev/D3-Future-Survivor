# Scripts/ui/choose_class_menu.gd
extends Control

const CLASS_CARD_SCENE = preload("res://Scenes/ui/class_card.tscn")
const CLASSES_PATH = "res://Classes"

@onready var cards_container: HBoxContainer = $MarginContainer/HBoxContainer/ClassList/CardsContainer
@onready var class_name_label: Label = $MarginContainer/HBoxContainer/ClassDetails/VBox/ClassNameLabel
@onready var class_description_label: Label = $MarginContainer/HBoxContainer/ClassDetails/VBox/ClassDescriptionLabel
@onready var start_button: Button = $MarginContainer/HBoxContainer/ClassDetails/VBox/StartButton

var _available_classes: Array[PlayerClass] = []
var _selected_class: PlayerClass = null

func _ready() -> void:
	start_button.disabled = true
	start_button.pressed.connect(_on_start_button_pressed)
	_load_classes()
	_populate_class_cards()

func _load_classes() -> void:
	var dir = DirAccess.open(CLASSES_PATH)
	if not dir:
		printerr("Diretório de Classes não encontrado em: " + CLASSES_PATH)
		return
		
	for file_name in dir.get_files():
		# --- CORREÇÃO PRINCIPAL AQUI ---
		# Verifica se o ficheiro termina com .tres ou .tres.remap
		if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			var full_path = CLASSES_PATH.path_join(file_name)
			
			# No jogo exportado, precisamos de remover o ".remap" para que o 'load' funcione
			if full_path.ends_with(".remap"):
				full_path = full_path.trim_suffix(".remap")

			var class_resource = load(full_path)
			if class_resource is PlayerClass:
				_available_classes.append(class_resource)

func _populate_class_cards() -> void:
	for class_data in _available_classes:
		var card = CLASS_CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.set_class_data(class_data)
		card.selected.connect(_on_class_selected)
	
	if not _available_classes.is_empty():
		_on_class_selected(_available_classes[0])
	else:
		# Mensagem de erro caso nada seja carregado
		class_name_label.text = "Nenhuma Classe Encontrada"
		class_description_label.text = "Verifique se as classes foram exportadas corretamente com o jogo."

func _on_class_selected(class_data: PlayerClass) -> void:
	_selected_class = class_data
	class_name_label.text = class_data.name_class
	class_description_label.text = class_data.description
	start_button.disabled = false

func _on_start_button_pressed() -> void:
	if not _selected_class:
		return
	
	GameSession.chosen_class = _selected_class
	get_tree().change_scene_to_file("res://Scenes/main/world.tscn")
