class_name DelayedMendPassive
extends Passive
## M-PATH's passive: a share of the health he loses to damage comes back as healing a few
## seconds later.

## Share of the health lost that comes back (0.15 = 15%).
@export_range(0.0, 1.0, 0.05) var share: float = 0.15
## Seconds before it comes back.
@export var delay: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(MendStatus.new(share, delay))


class MendStatus extends Status:
	var share: float
	var delay: float
	var _seen := 0.0          # the unit's damage_taken already accounted for
	var _queue: Array = []    # [time left, amount] pairs waiting to heal

	func _init(p_share: float, p_delay: float) -> void:
		share = p_share
		delay = p_delay

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		var lost := unit.damage_taken - _seen
		if lost > 0.0:
			_seen = unit.damage_taken
			_queue.append([delay, lost * share])
		for entry in _queue.duplicate():
			entry[0] -= delta
			if entry[0] <= 0.0:
				_queue.erase(entry)
				unit.heal(entry[1], unit.get_instance_id())

	## Health still waiting to come back, for anything that wants to show it.
	func pending(_unit: BattleUnit) -> float:
		var total := 0.0
		for entry in _queue:
			total += entry[1]
		return total
