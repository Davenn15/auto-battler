class_name CtrlPassive
extends Passive
## CTRL(R)'s passive: its wards rise with every enemy targeting it, and the first time it
## drops below each health threshold it launches a siphon drone (see CtrlDrones).

## Added to all three wards per enemy whose target is CTRL(R).
@export var ward_per_targeter: float = 10.0
## Most targeting enemies counted (5 = at most +50).
@export var max_targeters: int = 5
## Health shares (of max) that each launch one siphon drone the first time it drops below.
@export var thresholds: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
## Share of the enemy's max health those drones drain.
@export_range(0.0, 1.0, 0.01) var drain_share: float = 0.08
## How far the drone looks for an enemy, in hex cells (if none is that close, it goes
## for the enemy with the most health anywhere).
@export var range_cells: int = 3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(CtrlStatus.new(self))


class CtrlStatus extends Status:
	var passive: CtrlPassive
	var targeters := 0          # enemies targeting CTRL(R), counted each tick
	var _next_threshold := 0    # index of the next threshold still to trigger

	func _init(p_passive: CtrlPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, _delta: float) -> void:
		if not unit.active:
			return
		var count := 0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team and enemy.target == unit:
				count += 1
		targeters = mini(count, passive.max_targeters)
		# One drone per threshold crossed (a big hit can cross both at once).
		while _next_threshold < passive.thresholds.size() \
				and unit.health < unit.max_health * passive.thresholds[_next_threshold]:
			_next_threshold += 1
			_launch(unit)

	func _launch(unit: BattleUnit) -> void:
		var picks := CtrlDrones.siphon_targets(unit, passive.range_cells, 1)
		var victim: BattleUnit = picks[0] if not picks.is_empty() else _strongest_anywhere(unit)
		if victim == null:
			return
		unit.show_float_text("Siphon", CtrlDrones.COLOR)
		CtrlDrones.launch_siphon(unit, victim, passive.drain_share, passive.range_cells)

	func _strongest_anywhere(unit: BattleUnit) -> BattleUnit:
		var picks := CtrlDrones.siphon_targets(unit, 999, 1)
		return picks[0] if not picks.is_empty() else null

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
			return value + passive.ward_per_targeter * targeters
		return value
