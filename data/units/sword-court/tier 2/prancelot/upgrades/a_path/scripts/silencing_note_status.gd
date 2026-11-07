class_name SilencingNoteStatus
extends NoteStatus
## Sends a silencing note to the nearby enemy with the most charge: it can't gain charge
## or cast its Gambit for a while.

var duration: float


func _init(p_every: int, p_range_cells: int, p_duration: float) -> void:
	super(p_every, p_range_cells)
	duration = p_duration
	color = Color(0.75, 0.6, 1.0)   # muted violet


func _pick_target(unit: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in unit.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not unit._is_valid_target(enemy) \
				or unit.grid.get_distance(unit.cell, enemy.cell) > range_cells:
			continue
		if best == null or enemy.charge > best.charge:
			best = enemy
	return best


func _arrive(unit, target: BattleUnit, strength: float) -> void:
	# An item can let control effects wrack, lengthening the silence.
	var control: float = unit.wrack_effect_multiplier(Stats.EffectKind.CONTROL) if is_instance_valid(unit) else 1.0
	target.add_status(SilenceStatus.new(duration * strength * control))
