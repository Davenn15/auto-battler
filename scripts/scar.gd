class_name Scar
extends Status
## The Scar keyword (Stats.Stat.SCAR, always with a percentage): a unit with X% Scar gets X%
## of the health each hit takes back as healing Stats.SCAR_DELAY seconds later. Sources add
## together (Quickscar, M-Path's passive, Quickscar's Health Empower).
##
## Every unit carries one of these from the start of combat; it does nothing without Scar.

const COLOR := Color(0.95, 0.5, 0.55)   # a healing-scar pink

var _seen := 0.0       # the unit's damage_taken already accounted for
var _queue: Array = []   # [seconds left, amount] waiting to heal


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func tick(unit: BattleUnit, delta: float) -> void:
	var lost := unit.damage_taken - _seen
	if lost > 0.0:
		_seen = unit.damage_taken
		var share := unit.get_stat(Stats.Stat.SCAR) / 100.0
		if share > 0.0:
			_queue.append([Stats.SCAR_DELAY, lost * share])
	if _queue.is_empty() or not unit.active:
		return
	for entry in _queue.duplicate():
		entry[0] -= delta
		if entry[0] <= 0.0:
			_queue.erase(entry)
			var before := unit.health
			unit.heal(entry[1], unit.get_instance_id())
			if unit.health > before:
				KeepsakeVfx.heal_flash(unit)


## Health still waiting to come back, shown on the health bar.
func get_pending_healing(_unit: BattleUnit) -> float:
	var total := 0.0
	for entry in _queue:
		total += entry[1]
	return total
