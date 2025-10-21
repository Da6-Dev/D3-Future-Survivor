extends Resource
class_name PlayerClass

@export_group("Class Info")
@export var name_class: String = "Nova Classe"
@export_multiline var description: String = "Descrição da classe."

@export_group("Starting Stats")
@export var max_health: int = 100
@export var speed: float = 300.0

@export_group("Starting Ability")
@export var starting_ability_scene: PackedScene
