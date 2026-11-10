class_name BurstFirePassive
extends Passive
## VE5TIBULE's passive: each attack comes out as a quick burst of shots, each dealing an even
## share of the attack's damage. Every shot rolls its own wrack and runs on-hit effects, but
## only the first builds his Charge, so a burst charges him like one attack.

@export var shots: int = 3
## Seconds between shots in a burst.
@export var interval: float = 0.1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BurstStatus.new(shots, interval))


class BurstStatus extends Status:
	var shots: int
	var interval: float
	var _queue: Array = []   # [time left, target] for shots still to fire
	var _following := false  # true while firing a follow-up shot, so it doesn't start a burst

	func _init(p_shots: int, p_interval: float) -> void:
		shots = maxi(p_shots, 1)
		interval = p_interval

	func modify_outgoing_damage(_unit: BattleUnit, damage: float) -> float:
		return damage / shots

	func on_attack(unit: BattleUnit) -> void:
		if _following:
			return
		for i in range(1, shots):
			_queue.append([interval * i, unit.target])

	func tick(unit: BattleUnit, delta: float) -> void:
		for entry in _queue.duplicate():
			entry[0] -= delta
			if entry[0] > 0.0:
				continue
			_queue.erase(entry)
			var target = entry[1]
			if not unit.active or not is_instance_valid(target) or not target.alive:
				continue
			_fire(unit, target)

	## A follow-up shot: a full attack (wrack, on-hit effects) that doesn't disturb his attack
	## rhythm or build his Charge.
	func _fire(unit: BattleUnit, target: BattleUnit) -> void:
		var shot := Projectile.new()
		shot.grants_charge = false
		var timer := unit._attack_timer
		var total := unit._attack_cooldown_total
		_following = true
		unit.attack_now(target, 0.0, 0.0, shot)
		_following = false
		unit._attack_timer = timer
		unit._attack_cooldown_total = total
