class_name LastingWardsEffect
extends Passive
## Grouser's hero Ascension: every increase to his Wards, from any source (his A1 Ward Steal,
## an ally's buff, a Keepsake...), lasts the rest of combat, and the Ward reductions he puts
## on enemies (his passive's shred, A's, Clamp's) never wear off.
##
## Increases: each status on him is watched for what it adds to each Ward. When what it
## adds drops below the most it ever added (it wore off, ended, or he left a bubble), the
## difference is kept for the rest of combat. Reductions: WardShiftStatus.shred checks for
## the marker (has_on).


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(KeepStatus.new())


## True if `grouser` has the Ascension (his shreds then never wear off).
static func has_on(grouser: BattleUnit) -> bool:
	if not is_instance_valid(grouser):
		return false
	for status in grouser.statuses:
		if status is KeepStatus:
			return true
	return false


class KeepStatus extends Status:
	const WARDS := [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]
	## Per watched status (by instance id): {ward: the most it has added}.
	var _peak := {}
	## Per watched status still on him: {ward: what it adds now}.
	var _now := {}
	## What's kept per ward: the sum of every status's peak minus what it adds now.
	var _kept := {Stats.Stat.MIGHT_WARD: 0.0, Stats.Stat.INSIGHT_WARD: 0.0, Stats.Stat.CELERITY_WARD: 0.0}

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + _kept.get(stat, 0.0)

	func tick(unit: BattleUnit, _delta: float) -> void:
		var seen := {}
		for status: Status in unit.statuses.duplicate():
			if status == self:
				continue
			var id := status.get_instance_id()
			seen[id] = true
			var now := {}
			for ward in WARDS:
				var base := unit.data.get_base_stat(ward) if unit.data != null else 0.0
				var added := status.modify_stat(unit, ward, base) - base
				now[ward] = maxf(added, 0.0)
			_now[id] = now
			var peak: Dictionary = _peak.get(id, {})
			for ward in WARDS:
				peak[ward] = maxf(peak.get(ward, 0.0), now[ward])
			_peak[id] = peak
		for id in _now.keys():
			if not seen.has(id):
				_now.erase(id)   # it's gone: all of its peak is kept
		var kept := {}
		for ward in WARDS:
			var total := 0.0
			for id in _peak:
				var current: float = _now[id][ward] if _now.has(id) else 0.0
				total += _peak[id][ward] - current
			kept[ward] = total
		if kept != _kept:
			_kept = kept
