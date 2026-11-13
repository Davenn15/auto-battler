class_name MotherBeamPassive
extends Passive
## MOTHER-CHIP B: her attacks become a continuous beam (MotherBeamStatus), and her Chips
## beam her target alongside her. The beam deals more the lower its target's health.

## Seconds the beam charges up after switching targets before it deals damage.
@export var retarget_delay: float = 0.4
## Extra damage at 0% health: 1.0 = up to double damage, scaling with health missing.
@export var execute_bonus: float = 1.0


func on_battle_start(unit: BattleUnit) -> void:
	var beam := MotherBeamStatus.new(retarget_delay)
	beam.execute_bonus = execute_bonus
	unit.add_status(beam)
