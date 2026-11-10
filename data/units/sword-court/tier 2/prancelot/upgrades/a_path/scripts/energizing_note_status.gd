class_name EnergizingNoteStatus
extends NoteStatus
## Sends an energizing note to the nearby ally (never himself) with the least Celerity,
## giving it Celerity for a while.

var amount: float
var duration: float


func _init(p_every: int, p_range_cells: int, p_amount: float, p_duration: float) -> void:
	super(p_every, p_range_cells)
	amount = p_amount
	duration = p_duration
	color = Color(1.0, 0.85, 0.3)   # bright yellow


func _pick_target(unit: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for ally in _units_in_range(unit, unit.team):
		if best == null or ally.get_stat(Stats.Stat.CELERITY) < best.get_stat(Stats.Stat.CELERITY):
			best = ally
	return best


func _arrive(_unit, target: BattleUnit, strength: float) -> void:
	target.add_status(TimedStatStatus.new(Stats.Stat.CELERITY, amount * strength, duration))
