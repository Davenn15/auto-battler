class_name PhaseGambit
extends Gambit
## VE5TIBULE phases the enemy within range that has dealt the most damage this combat: it's
## stunned and untargetable for a while, taken out of the fight.

## How close the enemy must be, in hex cells.
@export var range_cells: int = 3
@export var duration: float = 3.0


func can_use(caster: BattleUnit) -> bool:
	return _pick_enemy(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var enemy := _pick_enemy(caster)
	if enemy == null:
		return
	phase(enemy, duration, caster)
	caster.show_float_text("Phase", PHASE_COLOR)


## Stuns `unit` and makes it untargetable for `duration` seconds, tinted blue.
static func phase(unit: BattleUnit, time: float, source: BattleUnit = null) -> void:
	unit.stun(time, source)
	unit.add_status(UntargetableStatus.new(time))
	KeepsakeVfx.phase_tint(unit, time)
	unit.show_float_text("Phased", PHASE_COLOR)


## True while `unit` is phased: stunned and untargetable at once (this Gambit, BAR.RAJ's
## passive, the Phase Button keepsake).
static func is_phased(unit: BattleUnit) -> bool:
	if unit == null or not unit.alive or unit._stunned_time <= 0.0:
		return false
	for status in unit.statuses:
		if status is UntargetableStatus:
			return true
	return false


## The enemy in range that has dealt the most damage this combat (ties go to the nearest),
## skipping any that are already out of reach or immune to crowd control.
func _pick_enemy(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable() or unit.is_cc_immune():
			continue
		var distance := caster.grid.get_distance(caster.cell, unit.cell)
		if distance > range_cells:
			continue
		if best == null or unit.damage_dealt > best.damage_dealt \
				or (unit.damage_dealt == best.damage_dealt and distance < caster.grid.get_distance(caster.cell, best.cell)):
			best = unit
	return best


const PHASE_COLOR := Color(0.55, 0.8, 1.0)
