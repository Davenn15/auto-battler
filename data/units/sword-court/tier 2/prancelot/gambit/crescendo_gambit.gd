class_name CrescendoGambit
extends Gambit
## Plays faster for a while: extra Celerity, and stronger notes.

@export var duration: float = 6.0
## At baseline 100, +60 is 60% faster attacks, so more notes too.
@export var celerity_bonus: float = 60.0
## Multiplies note strength while it lasts (1.75 = 75% stronger).
@export var note_potency: float = 1.75


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Recasting refreshes the crescendo instead of stacking a second one.
	for status in caster.statuses.duplicate():
		if status is CrescendoStatus:
			caster.remove_status(status)
	caster.add_status(CrescendoStatus.new(duration, celerity_bonus, note_potency))
	caster.show_float_text("Crescendo", Color(0.745, 0.345, 0.596, 1.0))
