class_name ShredTriplePassive
extends Passive
## SHRED: three separate attacks on three separate attack timers. Each timer runs at the
## normal attack speed, a third of an interval apart, and each attack deals 1/Attacks of
## a normal attack. So SHRED attacks three times as often for the same damage. Each one
## is a full attack for on-hit effects and Hit Effects, but gives only 1/Attacks of the
## Charge an attack gives, so Charge builds at the normal rate.
## (The three staggered timers are run as one timer ticking three times as fast: the same
## rhythm, and Celerity, stuns and slows affect all three alike.)

@export var attacks: int = 3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(TripleStatus.new(self))


class TripleStatus extends Status:
	var passive: ShredTriplePassive
	var _fired := 0   # attacks made so far in the current set of three

	func _init(p_passive: ShredTriplePassive) -> void:
		passive = p_passive

	## The attack bar is split into thirds and fills across all three attacks: each third
	## fills as one attack winds up, so you can see each of them land.
	func on_applied(unit: BattleUnit) -> void:
		unit.set_attack_bar_segments(maxi(passive.attacks, 1))

	func on_removed(unit: BattleUnit) -> void:
		unit.set_attack_bar_segments(1)

	func on_attack(_unit: BattleUnit) -> void:
		_fired = (_fired + 1) % maxi(passive.attacks, 1)

	func modify_attack_bar(_unit: BattleUnit, value: float) -> float:
		var n := maxi(passive.attacks, 1)
		return (_fired + clampf(value, 0.0, 1.0)) / n

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_attack_cooldown(_unit: BattleUnit, cooldown: float) -> float:
		return cooldown / maxi(passive.attacks, 1)

	func modify_outgoing_damage(_unit: BattleUnit, damage: float) -> float:
		return damage / maxi(passive.attacks, 1)

	func modify_own_attack_charge(_unit: BattleUnit, amount: float) -> float:
		return amount / maxi(passive.attacks, 1)
