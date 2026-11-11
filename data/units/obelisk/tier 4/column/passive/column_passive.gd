class_name ColumnPassive
extends Passive
## COLUMN is a structure: it can't move, can't gain Charge, is immune to crowd control,
## and never makes normal attacks.
## Everything it does comes from its weapons (ColumnWeapon passives), each on its own timer.


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StructureStatus.new())


class StructureStatus extends Status:
	func blocks_movement(_unit: BattleUnit) -> bool:
		return true

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return true

	func blocks_crowd_control(_unit: BattleUnit) -> bool:
		return true

	func tick(unit: BattleUnit, _delta: float) -> void:
		unit._attack_timer = maxf(unit._attack_timer, 1.0)   # its weapons are its only attacks
		unit.charge = 0.0
