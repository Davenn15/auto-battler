class_name ColumnShardPrintWeapon
extends ColumnWeapon
## B2: prints a random Shard and gives it to the nearby ally with the fewest keepsakes (and a
## free slot). Like VE5TIBULE's gifts, it's taken back when combat ends.

## How close the ally must be, in hex cells.
@export var range_cells: int = 3


func fire(unit: BattleUnit) -> bool:
	var ally := _pick_ally(unit)
	if ally == null:
		return false
	var shard: Keepsake = CombatRng.pick(MatchRules.shards())
	if shard == null:
		return false
	ally.swap_keepsake_in_combat(shard)
	ally.add_status(ShardGiftGambit.TempItemStatus.new(shard, null))
	KeepsakeVfx.gift_icon(unit.global_position, ally, shard)
	ally.show_float_text("+" + shard.get_display_name(), ColumnWeapon.LIGHT)
	return true


## The ally in range (not COLUMN, not a summon) with a free slot and the fewest keepsakes;
## ties go to the nearest.
func _pick_ally(unit: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other == null or other == unit or not other.alive or not other.active or other.team != unit.team \
				or other.is_summon or other.keepsakes.size() >= BattleUnit.MAX_KEEPSAKES:
			continue
		var distance := unit.grid.get_distance(unit.cell, other.cell)
		if distance > range_cells:
			continue
		if best == null or other.keepsakes.size() < best.keepsakes.size() \
				or (other.keepsakes.size() == best.keepsakes.size() and distance < unit.grid.get_distance(unit.cell, best.cell)):
			best = other
	return best
