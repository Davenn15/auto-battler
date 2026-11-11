class_name WardShiftStatus
extends Status
## Timed changes to a unit's wards that stack: Grouser's shredding takes wards away from
## enemies (negative), and with A1 he gains what he takes (positive). Each change wears off
## on its own. One of these per unit holds all of them.

const COLOR := Color(0.9, 1.0, 0.1)   # Grouser's neon yellow
const GLOW_KEY := "VfxGrouserShred"
const WARDS := [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]

var _entries: Array = []   # [stat, amount, time left]


## Grouser takes `amount` of `stat` (a ward) from `target` for `duration` seconds. If he can
## steal wards (A1), he gains the same for `steal_time` seconds.
static func shred(grouser: BattleUnit, target: BattleUnit, stat: Stats.Stat, amount: float, duration: float) -> void:
	if not is_instance_valid(target) or not target.alive or amount <= 0.0:
		return
	_on(target).add(stat, -amount, duration)
	if is_instance_valid(grouser) and grouser.alive:
		for status in grouser.statuses:
			if status is WardStealPassive.StealStatus:
				_on(grouser).add(stat, amount, status.duration)
				break


## The ward `target` has the most of right now.
static func highest_ward(target: BattleUnit) -> Stats.Stat:
	var best := WARDS[0] as Stats.Stat
	for stat in WARDS:
		if target.get_stat(stat) > target.get_stat(best):
			best = stat
	return best


static func _on(unit: BattleUnit) -> WardShiftStatus:
	for status in unit.statuses:
		if status is WardShiftStatus:
			return status
	var shift := WardShiftStatus.new()
	unit.add_status(shift)
	return shift


var _holder   # untyped: may be freed


func on_applied(unit: BattleUnit) -> void:
	_holder = unit


func on_removed(unit: BattleUnit) -> void:
	KeepsakeVfx.clear(unit, GLOW_KEY)


func add(stat: Stats.Stat, amount: float, duration: float) -> void:
	if amount < 0.0 and is_instance_valid(_holder):
		duration *= _holder.debuff_multiplier()   # a shred wears off sooner on units that resist debuffs
	_entries.append([stat, amount, duration])
	_update_glow()


## Someone else's debuff, or a gain from his own attacks: never stops Charge.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	for entry in _entries:
		if entry[0] == stat:
			value += entry[1]
	return value


func tick(_unit_ref: BattleUnit, delta: float) -> void:
	var changed := false
	for entry in _entries.duplicate():
		entry[2] -= delta
		if entry[2] <= 0.0:
			_entries.erase(entry)
			changed = true
	if changed:
		_update_glow()


## A neon yellow glow that grows with how much ward is shifted.
func _update_glow() -> void:
	if not is_instance_valid(_holder):
		return
	var total := 0.0
	for entry in _entries:
		total += absf(entry[1])
	if total <= 0.0:
		KeepsakeVfx.clear(_holder, GLOW_KEY)
	else:
		KeepsakeVfx.set_glow(_holder, GLOW_KEY, Color(COLOR, 0.6), clampf(total / 80.0, 0.0, 0.5))
