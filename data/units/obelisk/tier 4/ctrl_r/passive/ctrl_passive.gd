class_name CtrlPassive
extends Passive
## CTRL(R)'s passive: every time it takes damage it gains Ward of that damage's type for a
## while, and the first time it drops below each health threshold it launches a siphon
## drone (see CtrlDrones).

## Ward of the damage's type gained per hit taken, for Ward Duration seconds each.
@export var ward_per_hit: float = 5.0
@export var ward_duration: float = 3.0
## Most Ward of one type it can have from this at once.
@export var ward_cap: float = 40.0
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
	const WARDS := [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]
	var passive: CtrlPassive
	var _next_threshold := 0    # index of the next threshold still to trigger
	## Per damage type: the time left on each Ward stack it has from hits.
	var _stacks := [[], [], []]

	func _init(p_passive: CtrlPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	## Any damage that reaches it (after wards, so a fully shielded hit still counts) adds a
	## Ward stack of that damage's type, if it's under the cap.
	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		if damage > 0.0 and unit.incoming_is_hit and unit.incoming_damage_type != Stats.DamageType.PURE:   # Pure has no Ward
			var stacks: Array = _stacks[clampi(unit.incoming_damage_type, 0, 2)]
			if (stacks.size() + 1) * passive.ward_per_hit <= passive.ward_cap:
				stacks.append(passive.ward_duration)
			else:
				# At the cap: the oldest stack is refreshed instead.
				stacks.pop_front()
				stacks.append(passive.ward_duration)
		return damage

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		for stacks in _stacks:
			for i in range(stacks.size() - 1, -1, -1):
				stacks[i] -= delta
				if stacks[i] <= 0.0:
					stacks.remove_at(i)
		# One drone per threshold crossed (a big hit can cross both at once).
		while _next_threshold < passive.thresholds.size() 				and unit.health < unit.max_health * passive.thresholds[_next_threshold]:
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
		var i := WARDS.find(stat)
		if i >= 0:
			return value + minf(_stacks[i].size() * passive.ward_per_hit, passive.ward_cap)
		return value
