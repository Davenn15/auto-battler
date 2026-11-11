class_name BeamngPassive
extends Passive
## BEAM.NG's passive. Its attack is a continuous beam (like Scour's), and its damage and
## shielding grow the farther it is from its target: Bonus Per Cell for every cell past
## the first.
## Its B path makes its beams trigger once-per-attack effects more often (see
## ProcBoostPassive).

const COLOR := Color(0.95, 0.74, 0.55)   # pale, washed-out orange
const LIGHT := Color(1.0, 0.9, 0.8)

## Extra damage and shielding per cell of distance past the first (0.1 = +10% per cell).
@export var bonus_per_cell: float = 0.1
## Seconds the beam charges up after switching targets before it deals damage.
@export var retarget_delay: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	var beam := BeamngBeamStatus.new(retarget_delay)
	beam.bonus_per_cell = bonus_per_cell
	unit.add_status(beam)


## What BEAM.NG's damage or shielding at `target` is multiplied by, from the distance.
static func distance_multiplier(unit: BattleUnit, target: BattleUnit) -> float:
	if not is_instance_valid(target):
		return 1.0
	var per_cell := 0.0
	for status in unit.statuses:
		if status is BeamngBeamStatus:
			per_cell = status.bonus_per_cell
	var cells := maxi(unit.grid.get_distance(unit.cell, target.cell) - 1, 0)
	return 1.0 + per_cell * cells


## How often its beams trigger once-per-attack effects (1 = normal, 1.3 = 30% more often).
static func proc_rate(unit: BattleUnit) -> float:
	var rate := 1.0
	for status in unit.statuses:
		if status is ProcBoostPassive.ProcBoostStatus:
			rate += status.bonus
	return rate
