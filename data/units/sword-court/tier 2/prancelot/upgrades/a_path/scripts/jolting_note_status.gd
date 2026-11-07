class_name JoltingNoteStatus
extends NoteStatus
## Sends a jolting note to the nearby ally (him included) who has dealt the most damage
## this combat, giving it wrack chance for a while.

var amount: float
var duration: float


func _init(p_every: int, p_range_cells: int, p_amount: float, p_duration: float) -> void:
	super(p_every, p_range_cells)
	amount = p_amount
	duration = p_duration
	color = Color(0.4, 0.8, 1.0)   # electric blue


func _pick_target(unit: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for ally in _units_in_range(unit, unit.team):
		if best == null or ally.damage_dealt > best.damage_dealt:
			best = ally
	return best


func _arrive(_unit, target: BattleUnit, strength: float) -> void:
	target.add_status(TimedStatStatus.new(Stats.Stat.WRACK_CHANCE, amount * strength, duration))
