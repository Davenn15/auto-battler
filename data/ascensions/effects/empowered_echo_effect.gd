class_name EmpoweredEchoEffect
extends Passive
## An Ascension effect (Long Knives): the unit gains attack range, and its empowered attacks
## (the ones his passive empowers after each Gambit, see EmpowerStatus) trigger their Hit Effects Extra more
## times (see Status.extra_hit_effect_runs).

@export var range_bonus: int = 1
@export var extra: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.attack_range += range_bonus   # after the unit's stats are set up for the fight
	unit.add_status(EchoStatus.new(extra))


class EchoStatus extends Status:
	var extra: int
	var _left := 0          # empowered attacks still to come, counted here so the last one counts
	var _this_attack := false

	func _init(p_extra: int) -> void:
		extra = p_extra

	func on_applied(unit: BattleUnit) -> void:
		if not unit.status_added.is_connected(_on_status_added):
			unit.status_added.connect(_on_status_added)

	func on_removed(unit: BattleUnit) -> void:
		if is_instance_valid(unit) and unit.status_added.is_connected(_on_status_added):
			unit.status_added.disconnect(_on_status_added)

	func _on_status_added(_unit: BattleUnit, status: Status) -> void:
		if status is EmpowerStatus:
			_left = status.attacks_left

	func on_attack(_unit: BattleUnit) -> void:
		_this_attack = _left > 0
		if _this_attack:
			_left -= 1

	func extra_hit_effect_runs(_unit: BattleUnit) -> int:
		var runs := extra if _this_attack else 0
		_this_attack = false
		return runs
