class_name GatlingSpinPassive
extends Passive
## Gatling Gateling: every attack that hits the same target as the last one adds Celerity,
## up to a cap. Switching targets starts over.

@export var celerity_per_hit: float = 12.0
@export var max_celerity: float = 120.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GatlingSpinStatus.new(celerity_per_hit, max_celerity))


class GatlingSpinStatus extends Status:
	var per_hit: float
	var cap: float
	var bonus := 0.0
	var _last_target_id := 0

	func _init(p_per_hit: float, p_cap: float) -> void:
		per_hit = p_per_hit
		cap = p_cap

	func on_attack_hit(_unit: BattleUnit, target: BattleUnit, _dealt: float) -> void:
		var id := target.get_instance_id()
		if id == _last_target_id:
			bonus = minf(bonus + per_hit, cap)
		else:
			bonus = 0.0
			_last_target_id = id

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + bonus if stat == Stats.Stat.CELERITY else value
