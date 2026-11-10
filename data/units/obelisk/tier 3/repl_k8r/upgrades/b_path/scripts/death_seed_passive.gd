class_name DeathSeedPassive
extends Passive
## REPL\K8R B2: when a duplicate dies, it plants a replication seed in the nearby ally (not
## a REPL\K8R) with the lowest health, using its Gambit's seed settings.


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(DeathSeedStatus.new())


class DeathSeedStatus extends Status:
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		unit.died.connect(_on_died)

	func on_removed(unit: BattleUnit) -> void:
		if unit.died.is_connected(_on_died):
			unit.died.disconnect(_on_died)

	func _on_died(unit: BattleUnit) -> void:
		if unit.is_summon and unit.gambit is SeedGambit:   # duplicates only
			(unit.gambit as SeedGambit).plant(unit, unit.cell)
