class_name DelayedMendPassive
extends Passive
## M-Path's passive: Share x 100 percent Scar (see Scar): that share of the health he loses
## to each hit comes back as healing a few seconds later. Adds to any other Scar he has.

## Share of each hit that comes back (0.15 = 15% Scar).
@export_range(0.0, 1.0, 0.05) var share: float = 0.15
## Unused: Scar always comes back after Stats.SCAR_DELAY seconds. Kept so saved files load.
@export var delay: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StatBonusStatus.new(Stats.Stat.SCAR, share * 100.0))
