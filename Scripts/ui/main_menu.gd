extends Control

@onready var play_button: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/PlayButton
@onready var settings_button: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/SettingsButton
@onready var exit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/ExitButton
@onready var settings_menu: CanvasLayer = $SettingsMenu

func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main/choose_class_menu.tscn")

func _on_settings_button_pressed() -> void:
	settings_menu.open_menu()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
