class_name EmpowerGambit
extends Gambit
## Empowers the caster's next few attacks with bonus damage.

## Flat damage added to each empowered attack (before wrack is rolled).
@export var bonus_damage: float = 50.0
## Extra bonus damage per point of the caster's Insight.
@export var insight_scaling: float = 0.5
## How many of the caster's next attacks are empowered.
@export var attack_count: int = 3


## Won't cast while the previous empowerment is still active, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return not caster.statuses.any(func(s): return s is EmpowerStatus)


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	caster.add_status(EmpowerStatus.new(bonus_damage, insight_scaling, attack_count))
