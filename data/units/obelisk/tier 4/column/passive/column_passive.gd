class_name ColumnPassive
extends Passive
## COLUMN can't gain Charge and has 100 Immovability (immune to crowd control). It walks like a normal unit,
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

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + 100.0 if stat == Stats.Stat.IMMOVABILITY else value   # 100 Immovability: immune to crowd control

	func tick(unit: BattleUnit, _delta: float) -> void:
		unit._attack_timer = maxf(unit._attack_timer, 1.0)   # its weapons are its only attacks
		unit.charge = 0.0
