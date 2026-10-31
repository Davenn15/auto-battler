class_name DodgeBuildPassive
extends Passive
## Each time the unit takes damage, it gains dodge chance, until it dodges a hit.

## Dodge chance gained per hit taken (0.05 = +5%).
@export_range(0.0, 1.0, 0.01) var per_hit: float = 0.05
## The most dodge chance this can add.
@export_range(0.0, 1.0, 0.01) var max_bonus: float = 0.4


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(DodgeBuildStatus.new(per_hit, max_bonus))
