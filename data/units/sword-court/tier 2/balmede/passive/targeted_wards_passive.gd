class_name TargetedWardsPassive
extends Passive
## Balmede's passive: her wards rise for every enemy targeting her, counted live.

## Added to all three wards per enemy whose target is this unit.
@export var ward_per_targeter: float = 7.0
## Most targeting enemies counted (5 = at most +35).
@export var max_targeters: int = 5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(TargetedWardsStatus.new(self))


class TargetedWardsStatus extends Status:
	var passive: TargetedWardsPassive
	var targeters := 0   # enemies targeting this unit, counted each tick

	func _init(p_passive: TargetedWardsPassive) -> void:
		passive = p_passive

	func tick(unit: BattleUnit, _delta: float) -> void:
		if not unit.active:
			return
		var count := 0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team and enemy.target == unit:
				count += 1
		targeters = mini(count, passive.max_targeters)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
			return value + passive.ward_per_targeter * targeters
		return value
