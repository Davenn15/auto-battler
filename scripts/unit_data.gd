@tool

class_name UnitData
extends Resource
@export var display_name: String = "Unit"
@export var max_health: float = 1000.0
@export var attack_range: float = 1
@export var attack_cooldown: float = 2.0
@export_range(0.0, 1.0, 0.01) var wrack_chance: float = 0.25
@export_range(0.0, 5.0, 0.05, "or_greater") var wrack_damage: float = 0.3
@export var health_regen: float = 2.0   # health restored per second during combat

@export var passives: Array[Passive] = []

@export var gambit: Gambit
@export var max_charge: float = 100.0
@export var starting_charge: float = 0.0
@export var charge_on_attack: float = 10.0       # flat, when this unit's attack hits
@export var charge_on_hit: float = 2.0           # flat, when this unit takes an attack hit
@export var charge_per_damage: float = 0.01      # extra charge per point of damage taken

@export var sprite: Texture2D


@export_group("Attributes")
@export var might: float = 100.0
@export var insight: float = 100.0
@export var celerity: float = 100.0

@export_group("Wards")
@export var might_ward: float = 20.0
@export var insight_ward: float = 20.0
@export var celerity_ward: float = 20.0

@export_group("Combat")
## The damage type of this unit's basic attacks.
@export_enum("Might", "Insight", "Celerity") var attack_damage_type: int = 0


func get_base_stat(stat: Stats.Stat) -> float:
	match stat:
		Stats.Stat.MIGHT: return might
		Stats.Stat.INSIGHT: return insight
		Stats.Stat.CELERITY: return celerity
		Stats.Stat.MIGHT_WARD: return might_ward
		Stats.Stat.INSIGHT_WARD: return insight_ward
		Stats.Stat.CELERITY_WARD: return celerity_ward
		Stats.Stat.WRACK_CHANCE: return wrack_chance
		Stats.Stat.WRACK_DAMAGE: return wrack_damage
	return 0.0
