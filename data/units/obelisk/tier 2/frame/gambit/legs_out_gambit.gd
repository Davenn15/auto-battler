class_name LegsOutGambit
extends Gambit
## Frame: extends its legs, gaining Range Bonus attack range and Dodge chance for Duration
## seconds. Recasting starts it over.

@export var range_bonus: int = 1
@export_range(0.0, 1.0, 0.01) var dodge: float = 0.2
@export var duration: float = 4.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for status in caster.statuses.duplicate():
		if status is LegsOutStatus:
			caster.remove_status(status)
	caster.add_status(LegsOutStatus.new(self))
	caster.show_float_text("Legs out", FrameFx.LIGHT)


class LegsOutStatus extends Status:
	var gambit: LegsOutGambit
	var time_left: float

	func _init(p_gambit: LegsOutGambit) -> void:
		gambit = p_gambit
		time_left = p_gambit.duration

	func on_applied(unit: BattleUnit) -> void:
		unit.attack_range += gambit.range_bonus
		FrameFx.stretch(unit, 1.35)   # legs out

	func on_removed(unit: BattleUnit) -> void:
		unit.attack_range -= gambit.range_bonus
		FrameFx.stretch(unit, 1.0)

	func modify_dodge_chance(_unit: BattleUnit, chance: float) -> float:
		return chance + gambit.dodge

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
