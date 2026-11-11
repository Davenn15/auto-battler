class_name ColumnPhaseAllyWeapon
extends ColumnWeapon
## B1: Phases the hurt ally in range with the lowest share of its health (not COLUMN) for
## Phase Time seconds. The usual Phase rule applies: shorter if it has no fighting teammates.

@export var phase_time: float = 1.0


func fire(unit: BattleUnit) -> bool:
	var ally := ColumnWeapon.lowest_ally(unit, unit.attack_range, true)
	if ally == null or PhaseStatus.is_phased(ally):
		return false
	PhaseStatus.phase(ally, phase_time)
	return true
