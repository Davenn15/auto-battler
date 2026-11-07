class_name MarkGambit
extends Gambit
## Draws an X over the nearby enemy who has dealt the most damage this combat and goes
## after it. If that enemy dies before the X wears off, the caster gains a big shield.

## How close an enemy must be to be marked, in hex cells.
@export var mark_range_cells: int = 4
## Seconds the X lasts.
@export var mark_duration: float = 8.0
## Shield the caster gains if the marked enemy dies while the X is up.
@export var kill_shield: float = 400.0
@export var kill_shield_duration: float = 5.0
## Share of the marked enemy's wards removed (0.5 = halved). 0 = none.
@export_range(0.0, 1.0, 0.05) var ward_cut: float = 0.0
## Pistol shots loaded when she casts. 0 = none.
@export var shots_on_cast: int = 0

func can_use(caster: BattleUnit) -> bool:
	return _find_mark(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var target := _find_mark(caster)
	if target == null:
		return
	# Recasting replaces the old X.
	for status in caster.statuses.duplicate():
		if status is MarkHunterStatus:
			caster.remove_status(status)
	# An item can let control effects wrack, deepening the ward cut.
	var cut := minf(ward_cut * caster.wrack_effect_multiplier(Stats.EffectKind.CONTROL), 0.95)
	var mark := XMarkStatus.new(mark_duration, cut)
	target.add_status(mark)
	caster.add_status(MarkHunterStatus.new(target, mark, mark_duration, kill_shield, kill_shield_duration))
	caster.target = target
	if shots_on_cast > 0:
		for status in caster.statuses:
			if status is PistolStatus:
				status.load_shot(caster, shots_on_cast)
				break


## The targetable enemy in range who has dealt the most damage. Ties, like everyone at
## 0 early on, go to the nearest.
func _find_mark(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not caster._is_valid_target(unit):
			continue
		var dist := caster.grid.get_distance(caster.cell, unit.cell)
		if dist > mark_range_cells:
			continue
		if best == null or unit.damage_dealt > best.damage_dealt \
				or (unit.damage_dealt == best.damage_dealt and dist < caster.grid.get_distance(caster.cell, best.cell)):
			best = unit
	return best
