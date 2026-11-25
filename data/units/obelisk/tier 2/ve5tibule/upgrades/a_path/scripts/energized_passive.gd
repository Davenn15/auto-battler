class_name EnergizedPassive
extends Passive
## Vestibule A: each time he plays his Gambit he gains Voltage, after that Gambit's own
## clearing, so he keeps it until the next one.

@export var voltage: float = 10.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(EnergizedStatus.new(self))


class EnergizedStatus extends Status:
	var passive: EnergizedPassive

	func _init(p_passive: EnergizedPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_played(unit: BattleUnit) -> void:
		VoltageStatus.ensure(unit).add_after_gambit(passive.voltage)
		unit.show_float_text("+Voltage", VoltageStatus.LIGHT)
