class_name VirusRotPassive
extends Passive
## MOTHER-CHIP's A path, one passive per upgrade, each switching on its part:
##   A: enemies lose a share of their healing, shielding and wards for each Mono-Virus
##      stack on them, up to a cap.
##   A1: her team gains Charge every second for each Mono-Virus stack on enemies.
##   A2: enemies who die pass ALL their Mono-Virus stacks to their nearest ally, not half
##       (MonoVirusStatus checks for this passive's marker on a living enemy of theirs).

## A: share lost per stack (0.04 = 4%), and the most that can be lost.
@export_range(0.0, 1.0, 0.01) var rot_per_stack: float = 0.0
@export_range(0.0, 1.0, 0.05) var rot_cap: float = 0.6
## A1: Charge per second each ally gains for each Mono-Virus stack on enemies.
@export var charge_per_stack: float = 0.0
## A2: dying enemies pass on all their stacks.
@export var full_transfer: bool = false


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(RotSource.new(self))


## True if `dead`'s enemies include a living MOTHER-CHIP with A2.
static func full_transfer_against(dead: BattleUnit) -> bool:
	for node in dead.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == dead.team:
			continue
		for status in unit.statuses:
			if status is RotSource and status.passive.full_transfer:
				return true
	return false


class RotSource extends Status:
	const RECHECK := 0.25
	var passive: VirusRotPassive
	var _timer := 0.0

	func _init(p_passive: VirusRotPassive) -> void:
		passive = p_passive

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active or not unit.alive:
			return
		if passive.rot_per_stack > 0.0:
			_timer -= delta
			if _timer <= 0.0:
				_timer = RECHECK
				for node in unit.get_tree().get_nodes_in_group("units"):
					var enemy := node as BattleUnit
					if enemy != null and enemy.alive and enemy.team != unit.team and MonoVirusStatus.stacks_on(enemy) > 0:
						RotStatus.refresh_on(enemy, unit.get_instance_id(), passive.rot_per_stack, passive.rot_cap)
		if passive.charge_per_stack > 0.0:
			var stacks := 0
			for node in unit.get_tree().get_nodes_in_group("units"):
				var enemy := node as BattleUnit
				if enemy != null and enemy.alive and enemy.team != unit.team:
					stacks += MonoVirusStatus.stacks_on(enemy)
			if stacks > 0:
				for node in unit.get_tree().get_nodes_in_group("units"):
					var ally := node as BattleUnit
					if ally != null and ally.alive and ally.active and ally.team == unit.team:
						ally.gain_charge(passive.charge_per_stack * stacks * delta)


## On an enemy with Mono-Virus near a MOTHER-CHIP with A: less healing, shielding and wards
## for each stack (read live). Lasts a moment after its last refresh.
class RotStatus extends Status:
	const LINGER := 0.4
	const WARDS := [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]
	var source_id: int
	var per_stack: float
	var cap: float
	var _left := LINGER
	var _unit   # untyped: may be freed

	static func refresh_on(enemy: BattleUnit, p_source_id: int, p_per_stack: float, p_cap: float) -> void:
		for status in enemy.statuses:
			if status is RotStatus and status.source_id == p_source_id:
				status._left = LINGER
				return
		var rot := RotStatus.new()
		rot.source_id = p_source_id
		rot.per_stack = p_per_stack
		rot.cap = p_cap
		enemy.add_status(rot)

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		_unit = unit

	func _keep() -> float:
		if not is_instance_valid(_unit):
			return 1.0
		return 1.0 - minf(per_stack * MonoVirusStatus.stacks_on(_unit), cap)

	func modify_healing_received(_target: BattleUnit, amount: float) -> float:
		return amount * _keep()

	func modify_shield_received(_target: BattleUnit, amount: float) -> float:
		return amount * _keep()

	func modify_stat(_target: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value * _keep() if stat in WARDS else value

	func tick(unit: BattleUnit, delta: float) -> void:
		_left -= delta
		if _left <= 0.0:
			unit.remove_status(self)
