extends Resource
class_name PlayerStats

@export_group("Primary Stats")
@export var max_health: float = 100.0
@export var speed: float = 300.0
@export var damage_reduction_multiplier: float = 1.0
@export var health_regen_rate: float = 0.0

@export_group("Offense Stats")
@export var global_damage_multiplier: float = 1.0
@export var global_attack_speed_bonus: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 2.0

@export_group("Shield Stats")
@export var max_shield: float = 0.0
@export var shield_recharge_delay: float = 5.0
@export var shield_recharge_rate: float = 10.0

@export_group("Slots")
@export var ability_slots: int = 3
@export var passive_slots: int = 4
