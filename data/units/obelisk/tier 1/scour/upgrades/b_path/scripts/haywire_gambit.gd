class_name HaywireGambit
extends Gambit
## Scour goes haywire: dashes up to Dash Cells hexes to the spot where his blast would catch
## the most enemies, then detonates, damaging every enemy within Radius Cells and dying.
## He's dead afterwards, so he doesn't count toward the surviving Aura that damages the
## losing player. Damage per enemy = Damage + Might Scaling x Might.

@export var dash_cells: int = 3
@export var dash_time: float = 0.3
@export var radius_cells: int = 1
@export var damage: float = 250.0
@export var might_scaling: float = 1.5
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## B2: the blast ignores the enemies' wards.
@export var ignore_wards: bool = false


## Only goes off if some spot in reach would catch an enemy, so he doesn't blow up for nothing.
func can_use(caster: BattleUnit) -> bool:
	return _best_spot(caster)["count"] > 0


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var spot: Dictionary = _best_spot(caster)
	if spot["count"] <= 0:
		return
	if spot["cell"] != caster.cell:
		caster.lock_for(dash_time)
		await caster.dash_to(spot["cell"], dash_time)
	if not _alive(caster):
		return
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	KeepsakeVfx.haywire_blast(caster, radius_cells)
	caster.show_float_text("BOOM", HAYWIRE_COLOR)
	for enemy in _enemies_near(caster, caster.cell):
		var dealt := enemy.take_damage(hit, 0, damage_type, ignore_wards, caster)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
	caster.kill()


## {"cell": where to blow up, "count": enemies the blast would catch there}. His own cell
## or any free cell within dash range; ties go to the nearest.
func _best_spot(caster: BattleUnit) -> Dictionary:
	var best := {"cell": caster.cell, "count": _enemies_near(caster, caster.cell).size()}
	var cells := caster.grid.free_cells_in_range(caster.cell, dash_cells)
	cells.sort_custom(func(a, b): return caster.grid.get_distance(caster.cell, a) < caster.grid.get_distance(caster.cell, b))
	for cell in cells:
		var count := _enemies_near(caster, cell).size()
		if count > best["count"]:
			best = {"cell": cell, "count": count}
	return best


func _enemies_near(caster: BattleUnit, center: Vector2i) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable() \
				and caster.grid.get_distance(center, unit.cell) <= radius_cells:
			result.append(unit)
	return result


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


const HAYWIRE_COLOR := Color(1.0, 0.55, 0.15)
