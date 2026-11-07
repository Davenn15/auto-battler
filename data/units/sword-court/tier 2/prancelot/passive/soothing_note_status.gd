class_name SoothingNoteStatus
extends NoteStatus
## Sends a soothing note to the most hurt nearby ally (him included), giving it a burst
## of healing over time.

var heal_per_second: float
var duration: float


func _init(p_every: int, p_range_cells: int, p_heal_per_second: float, p_duration: float) -> void:
	super(p_every, p_range_cells)
	heal_per_second = p_heal_per_second
	duration = p_duration
	color = Color(0.5, 1.0, 0.6)   # soft green


## The ally in range missing the most of its health, as a share. Null if everyone's full.
func _pick_target(unit: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for ally in _units_in_range(unit, unit.team):
		if ally.health >= ally.max_health:
			continue
		if best == null or ally.health / ally.max_health < best.health / best.max_health:
			best = ally
	return best


func _arrive(unit, target: BattleUnit, strength: float) -> void:
	var source_id: int = unit.get_instance_id() if is_instance_valid(unit) else 0
	target.add_status(RegenBurstStatus.new(source_id, heal_per_second * strength, duration))
