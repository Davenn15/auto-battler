class_name AdoringGambit
extends Gambit
## Lunck rushes to the ally with the highest single attribute (Might, Insight, or
## Celerity) and gives them a large shield and extra wrack chance for a while.

@export var shield_amount: float = 350.0
@export var wrack_chance: float = 0.25   # 0.25 = +25% chance
## Seconds the shield and wrack chance last.
@export var duration: float = 5.0
## Charge Lunck gains each time the ally gets a kill. 0 = none.
@export var charge_on_kill: float = 0.0
## Whether Lunck gets the same shield and wrack chance himself.
@export var include_self: bool = false

const ATTRIBUTES := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY]


## Needs an ally to adore, so charge isn't wasted when he's alone.
func can_use(caster: BattleUnit) -> bool:
	return _pick_ally(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var ally := _pick_ally(caster)   # picked again: someone may have died while Acting
	if ally == null:
		return
	_rush_to(caster, ally)
	var recipients: Array[BattleUnit] = [ally]
	if include_self:
		recipients.append(caster)
	for unit in recipients:
		unit.add_shield(shield_amount, duration, caster.get_instance_id())
		unit.add_status(AdoredStatus.new(caster.get_instance_id(), wrack_chance, charge_on_kill, duration))
		KeepsakeVfx.head_icon(unit, "VfxAdoreHeart", KeepsakeVfx.HeadIcon.HEART, KeepsakeVfx.LUNCK_ORANGE, duration)


## The living ally (not Lunck) whose best attribute is highest.
func _pick_ally(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_value := -1.0
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive or unit.team != caster.team:
			continue
		var top := 0.0
		for stat in ATTRIBUTES:
			top = maxf(top, unit.get_stat(stat))
		if top > best_value:
			best_value = top
			best = unit
	return best


## Moves Lunck to the free cell next to `ally` that's closest to him. Stays put if
## he's already beside them or every cell around them is taken.
func _rush_to(caster: BattleUnit, ally: BattleUnit) -> void:
	if caster.grid.get_distance(caster.cell, ally.cell) <= 1:
		return
	var best := caster.cell
	var best_dist := INF
	for c in caster.grid.free_cells_in_range(ally.cell, 1):
		var d := caster.global_position.distance_squared_to(caster.grid.cell_to_world(c))
		if d < best_dist:
			best_dist = d
			best = c
	caster.place_at(best)
