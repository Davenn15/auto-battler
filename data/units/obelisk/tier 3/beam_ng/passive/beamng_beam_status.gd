class_name BeamngBeamStatus
extends BeamStatus
## BEAM.NG's beam: Scour's continuous beam (BeamStatus), in pale orange, stronger the
## farther its target is, and triggering effects more often with its B path.
## Its B Gambit also uses copies of this, not attached to BEAM.NG, to fire extra beams.

var bonus_per_cell: float = 0.1
## Extra multiplier for beams fired by its Gambit (1 = a normal attack's worth).
var scale: float = 1.0


func damage_multiplier(unit: BattleUnit, enemy: BattleUnit) -> float:
	return scale * BeamngPassive.distance_multiplier(unit, enemy)


func proc_rate(unit: BattleUnit) -> float:
	return BeamngPassive.proc_rate(unit)


func beam_color(_unit: BattleUnit) -> Color:
	return BeamngPassive.COLOR
