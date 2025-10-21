extends Control

const CLASS_CARD_SCENE = preload("res://Scenes/ui/class_card.tscn")
const CLASSES_PATH = "res://Player/Classes"
const PlayerClassScript = preload("res://Scripts/Resources/PlayerClass.gd")

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
	_available_classes.clear() 
	
	ResourceLoaderUtils.populate_resources_from_path(
		_available_classes,
		CLASSES_PATH,
		PlayerClassScript,
		true
	)

func _populate_class_cards() -> void:
	for class_data in _available_classes:
		var card = CLASS_CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.set_class_data(class_data)
		card.selected.connect(_on_class_selected)
	
	if not _available_classes.is_empty():
		_on_class_selected(_available_classes[0])
	else:
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
