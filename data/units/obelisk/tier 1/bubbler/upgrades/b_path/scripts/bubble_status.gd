class_name BubbleStatus
extends Status
## Being inside one of Bubbler's bubbles: extra wards for allies, or lost Celerity for
## enemies (with the B2 upgrade). The bubble refreshes it every physics step while the unit
## stays inside; it wears off a moment after the unit leaves or the bubble pops. Each bubble
## keeps its own, so two overlapping bubbles both count.

const LINGER := 0.15   # seconds it lasts after its last refresh

var bubble_id: int
var ward_bonus: float
var celerity_cut: float
var time_left := LINGER


func _init(p_bubble_id: int, p_ward: float, p_celerity_cut: float) -> void:
	bubble_id = p_bubble_id
	ward_bonus = p_ward
	celerity_cut = p_celerity_cut


## Refreshes the bubble's status on `unit`, adding it if the unit just stepped in.
static func refresh_on(unit: BattleUnit, p_bubble_id: int, p_ward: float, p_celerity_cut: float) -> void:
	for status in unit.statuses:
		if status is BubbleStatus and status.bubble_id == p_bubble_id:
			status.time_left = LINGER
			return
	unit.add_status(BubbleStatus.new(p_bubble_id, p_ward, p_celerity_cut))


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	match stat:
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD:
			return value + ward_bonus
		Stats.Stat.CELERITY:
			return value - celerity_cut
	return value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
