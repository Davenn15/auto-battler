class_name InsightDrainStatus
extends Status
## Lowers Insight while the unit stands in an Arcane Ring. The ring refreshes it every
## frame; once the unit leaves, or the ring is gone, it wears off shortly after.

const LINGER := 0.25   # seconds it lasts without a refresh

var source_id: int     # the ring, so two rings don't share one drain
var amount: float
var time_left: float = LINGER


func _init(p_source_id: int, p_amount: float) -> void:
	source_id = p_source_id
	amount = p_amount


func refresh() -> void:
	time_left = LINGER


func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.INSIGHT:
		return value - amount * unit.debuff_multiplier()
	return value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
