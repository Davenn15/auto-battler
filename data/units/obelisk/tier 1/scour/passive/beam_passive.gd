class_name BeamPassive
extends Passive
## Scour's attack is a continuous beam rather than shots (see BeamStatus).

## Seconds the beam charges up after switching targets before it deals damage.
@export var retarget_delay: float = 0.6


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BeamStatus.new(retarget_delay))
