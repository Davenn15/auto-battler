class_name FourthEdgeEffect
extends Passive
## SHRED's hero Ascension: its attack is split into Strikes strikes instead of 3 (each a
## 1/Strikes share of an attack and of its Charge), and it gains Vampirism as its health
## drops: none at full health, rising evenly to Max Vampirism near 0.

@export var strikes: int = 4
## 0.3 = 30% Vampirism near 0 health.
@export var max_vampirism: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	var status := EdgeStatus.new()
	status.effect = self
	unit.add_status(status)


class EdgeStatus extends Status:
	var effect: FourthEdgeEffect
	var _split := false

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	## Its passive may be added after this, so its strike count is changed on the first tick
	## (on its own copy of the passive).
	func tick(unit: BattleUnit, _delta: float) -> void:
		if _split:
			return
		_split = true
		for status in unit.statuses:
			if status is ShredTriplePassive.TripleStatus:
				status.passive = status.passive.duplicate() as ShredTriplePassive
				status.passive.attacks = effect.strikes
				unit.set_attack_bar_segments(effect.strikes)

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat != Stats.Stat.VAMPIRISM or unit.max_health <= 0.0:
			return value
		var missing := clampf(1.0 - unit.health / unit.max_health, 0.0, 1.0)
		return value + effect.max_vampirism * missing
