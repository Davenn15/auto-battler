class_name ColumnPassive
extends Passive
## COLUMN can't gain Charge and is immune to crowd control. It walks like a normal unit,
## but never makes normal attacks: everything it does comes from its weapons (ColumnWeapon
## passives), each on its own timer. Its base weapons are two continuous beams at two
## different enemies.


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ColumnStatus.new())


class ColumnStatus extends Status:
	func blocks_attacks(_unit: BattleUnit) -> bool:
		return true   # its weapons are its only attacks

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return true

	func blocks_crowd_control(_unit: BattleUnit) -> bool:
		return true

	func tick(unit: BattleUnit, _delta: float) -> void:
		unit._attack_timer = maxf(unit._attack_timer, 1.0)   # its weapons are its only attacks
		unit.charge = 0.0
