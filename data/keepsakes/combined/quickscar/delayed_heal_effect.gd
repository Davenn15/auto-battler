class_name DelayedHealEffect
extends Passive
## Quickscar: the unit has Share x 100 percent Scar (see Scar): that share of each hit it
## takes heals back a few seconds later. Adds to any other Scar it has.

@export_range(0.0, 1.0, 0.05) var share: float = 0.15


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StatBonusStatus.new(Stats.Stat.SCAR, share * 100.0))
