extends Resource
class_name AbilityUpgrade

# Enum para identificar o tipo de upgrade de forma clara
enum UpgradeType { 
	UNLOCK_NEW_ABILITY, # Desbloqueia uma nova habilidade
	UPGRADE_EXISTING_ABILITY, # Melhora uma habilidade existente
	APPLY_PASSIVE_STAT
}

# Enum para as raridades
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

# --- Informações Básicas (Visíveis na Carta) ---
@export_group("Card Info")
@export var id: StringName # Um identificador único, ex: "sword_damage_1"
@export var ability_name: String # Nome que aparece na carta, ex: "Ataque da Espada"
@export_multiline var description: String # O que o upgrade faz
@export var rarity: Rarity = Rarity.COMMON

# --- Lógica do Upgrade ---
@export_group("Upgrade Logic")
@export var type: UpgradeType = UpgradeType.UPGRADE_EXISTING_ABILITY

# Para qual habilidade este upgrade se aplica (usaremos o nome do Enum do player.gd)
# Ex: AbilityType.PRIMARY
@export var target_ability_id: StringName
@export var passive_stat_id: StringName

# Se for do tipo UNLOCK_NEW_ABILITY, esta é a cena da nova habilidade
@export var new_ability_scene: PackedScene 

# --- Atributos a serem Modificados ---
# Usamos um dicionário para poder aplicar vários bônus com uma única carta
# Exemplo: {"damage_amount": 5, "cooldown_time": -0.1}
@export var modifiers: Dictionary = {}
