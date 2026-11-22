class_name EmpowerPassive
extends Passive
## Silt: after he casts his Gambit (whichever path's), his next Attack Count attacks gain
## the Hit Effect: deal Bonus Damage + Insight Scaling x Insight as Insight damage. A and A1
## tune it (see EmpowerTuning): more empowered attacks, and the damage spread around the
## target. Casting again starts a fresh set.

@export var bonus_damage: float = 40.0
@export var insight_scaling: float = 0.2
@export var attack_count: int = 3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(EmpowerWatch.new(self))


## Watches for the Gambit finishing, then empowers the next attacks.
class EmpowerWatch extends Status:
	var passive: EmpowerPassive

	func _init(p_passive: EmpowerPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_finished(unit: BattleUnit) -> void:
		var extra := 0
		var splash := 0
		for p in unit.passives:
			if p is EmpowerTuning:
				extra += p.extra_attacks
				splash = maxi(splash, p.splash_radius)
		for status in unit.statuses.duplicate():
			if status is EmpowerStatus:
				unit.remove_status(status)   # a fresh set replaces what's left
		unit.add_status(EmpowerStatus.new(passive.bonus_damage, passive.insight_scaling,
				passive.attack_count + extra, splash))
