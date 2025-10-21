extends PanelContainer

signal selected(class_data: PlayerClass)

@onready var name_label: Label = $VBox/ClassNameLabel
@onready var select_button: Button = $VBox/SelectButton

var _class_data: PlayerClass

func _ready() -> void:
	select_button.pressed.connect(func(): emit_signal("selected", _class_data))

func set_class_data(class_data: PlayerClass) -> void:
	_class_data = class_data
	name_label.text = class_data.name_class
