extends Resource
class_name AbilityUpgrade

enum UpgradeType { 
	UNLOCK_NEW_ABILITY,
	UPGRADE_EXISTING_ABILITY,
	APPLY_PASSIVE_STAT
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export_group("Card Info")
@export var id: StringName
@export var ability_name: String
@export_multiline var description: String
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D

@export_group("Upgrade Logic")
@export var type: UpgradeType = UpgradeType.UPGRADE_EXISTING_ABILITY
@export var target_ability_id: StringName
@export var passive_stat_id: StringName
@export var new_ability_scene: PackedScene

@export_group("Attributes")
@export var modifiers: Dictionary = {}
