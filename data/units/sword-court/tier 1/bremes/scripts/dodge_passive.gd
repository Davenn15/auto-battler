class_name DodgePassive
extends Passive
## Gives the unit a chance to avoid any incoming hit entirely.

## Chance to dodge each hit (0.1 = 10%).
@export_range(0.0, 1.0, 0.01) var dodge_chance: float = 0.1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(DodgeStatus.new(dodge_chance))
