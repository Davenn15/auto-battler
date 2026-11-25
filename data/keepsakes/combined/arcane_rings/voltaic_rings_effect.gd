class_name VoltaicRingsEffect
extends Passive
## Voltaic Rings: the first time each combat the unit plays its Gambit, it gains Voltage
## (after that Gambit's own clearing, so it keeps it for the next one).
##   Insight Empower: the second play gives Second Play Share of that Voltage again.
##   Celerity Empower: the second Gambit's damage, shields and heals are Bonus Per Voltage
##   higher for each Voltage it spends (the Voltage the unit has when it plays), until the
##   unit casts again.

@export var voltage: float = 20.0
@export_range(0.0, 1.0, 0.05) var second_play_share: float = 0.0
## 0.02 = +2% per Voltage spent.
@export var bonus_per_voltage: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Rings.new(self))


class Rings extends Status:
	var effect: VoltaicRingsEffect
	var _plays := 0
	var _bonus := 0.0

	func _init(p_effect: VoltaicRingsEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit(_unit: BattleUnit) -> void:
		_bonus = 0.0   # a new cast: the second Gambit's boost is over

	func on_gambit_played(unit: BattleUnit) -> void:
		_plays += 1
		if _plays == 1:
			_give(unit, effect.voltage)
		elif _plays == 2:
			var spent := VoltageStatus.of(unit)
			_bonus = floorf(spent.stacks) * effect.bonus_per_voltage if spent != null else 0.0
			if effect.second_play_share > 0.0:
				_give(unit, effect.voltage * effect.second_play_share)

	func _give(unit: BattleUnit, amount: float) -> void:
		if amount <= 0.0:
			return
		VoltageStatus.ensure(unit).add_after_gambit(amount)
		unit.show_float_text("+%d Voltage" % roundi(amount), VoltageStatus.LIGHT)

	func gambit_damage_bonus(_unit: BattleUnit) -> float:
		return _bonus

	func modify_outgoing_support(_unit: BattleUnit, _target: BattleUnit, amount: float, _is_shield: bool, from_gambit: bool) -> float:
		return amount * (1.0 + _bonus) if from_gambit else amount
