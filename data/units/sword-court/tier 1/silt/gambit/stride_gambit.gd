class_name StrideGambit
extends Gambit
## Silt: gains Celerity for the rest of combat, stacking with every cast.

@export var celerity: float = 25.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	caster.add_status(PermanentStatStatus.new(Stats.Stat.CELERITY, celerity))   # counts as a permanent gain
	caster.show_float_text("+%d Celerity" % roundi(celerity), Color(1.0, 0.85, 0.35))
