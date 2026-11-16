class_name HinderStatus
extends Status
## Hinder: the unit's Might, Insight and Celerity are lowered by a share for a while.
## One per unit: Hindering it again refreshes the time (and keeps the stronger share).
## Resisting debuffs shortens it. Use HinderStatus.hinder() to apply it.

const TINT := Color(0.55, 0.45, 0.7)
const STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY]

var share: float
var time_left: float


func _init(p_share: float, p_duration: float) -> void:
	share = p_share
	time_left = p_duration


## Hinders `unit` by `share` (0.2 = 20% lower) for `duration` seconds, or refreshes the
## Hinder it already has.
static func hinder(unit: BattleUnit, p_share: float, duration: float) -> void:
	if not is_instance_valid(unit) or not unit.alive:
		return
	var time := duration * unit.debuff_multiplier()
	for status in unit.statuses:
		if status is HinderStatus:
			status.share = maxf(status.share, p_share)
			status.time_left = maxf(status.time_left, time)
			return
	unit.add_status(HinderStatus.new(p_share, time))
	unit.show_float_text("Hindered", TINT)


func modify_final_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	return value * (1.0 - share) if STATS.has(stat) else value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
