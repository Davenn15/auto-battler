class_name ColumnFabricatorWeapon
extends ColumnWeapon
## A2: manufactures a random full keepsake and magnetizes it to the nearest ally with an
## open keepsake slot, which equips it (for the rest of this combat only) and gains a
## Shield. If no ally has an open slot, the nearest ally still gets the Shield.

## Shield the ally gains, and how long it lasts.
@export var shield: float = 150.0
@export var shield_duration: float = 4.0


func fire(unit: BattleUnit) -> bool:
	var with_slot := _nearest_ally(unit, true)
	var ally := with_slot if with_slot != null else _nearest_ally(unit, false)
	if ally == null:
		return false   # no allies left: try again later
	if with_slot != null:
		var pool: Array = MatchRules.keepsakes()
		if not pool.is_empty():
			var made: Keepsake = CombatRng.pick(pool)
			ally.swap_keepsake_in_combat(made)
			ally.show_float_text(made.get_display_name(), ColumnWeapon.LIGHT)
			KeepsakeVfx.gift_icon(unit.global_position, ally, made)
	ally.add_shield(shield, shield_duration, unit.get_instance_id())
	return true


## The living ally (not COLUMN) nearest to it; with `need_slot`, only ones with a free
## keepsake slot. Ties go to the lower instance id, so it's the same on every machine.
func _nearest_ally(unit: BattleUnit, need_slot: bool) -> BattleUnit:
	var best: BattleUnit = null
	var best_distance := 0
	for node in unit.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally == null or ally == unit or not ally.alive or not ally.active or ally.team != unit.team:
			continue
		if need_slot and ally.keepsakes.size() >= BattleUnit.MAX_KEEPSAKES:
			continue
		var distance := unit.grid.get_distance(unit.cell, ally.cell)
		if best == null or distance < best_distance \
				or (distance == best_distance and ally.get_instance_id() < best.get_instance_id()):
			best = ally
			best_distance = distance
	return best
