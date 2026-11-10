class_name BurstChargeEffect
extends Passive
## Whenever the unit's attacks deal at least a share of one enemy's max health within a
## short window, it gains charge.

@export var share: float = 0.15
@export var window: float = 1.0
@export var charge: float = 5.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Tally.new(self))


class Tally extends Status:
	var effect: BurstChargeEffect
	var _time := 0.0
	var _hits := {}   # enemy instance id -> [[time, damage], ...]

	func _init(p_effect: BurstChargeEffect) -> void:
		effect = p_effect

	func tick(_unit: BattleUnit, delta: float) -> void:
		_time += delta

	func on_attack_hit(unit: BattleUnit, target: BattleUnit, dealt: float) -> void:
		var id := target.get_instance_id()
		var recent: Array = _hits.get(id, []).filter(func(h): return _time - h[0] <= effect.window)
		recent.append([_time, dealt])
		var total := 0.0
		for h in recent:
			total += h[1]
		if total >= target.max_health * effect.share:
			unit.gain_charge(effect.charge)
			KeepsakeVfx.burst(target)
			recent.clear()   # a fresh window, so one burst pays out once
		_hits[id] = recent
