class_name ShardGiftGambit
extends Gambit
## VE5TIBULE B: sends temporary Shards to nearby allies. An ally holding a Shard gets one
## that combines with it, and the two become their keepsake on the spot; an ally without one
## gets a random Shard in a free slot. Everything given is taken back when combat ends.
## Allies who can combine are picked first, then the nearest.
##   B1: one more ally.  B2: more range.

@export var targets: int = 2
## How close the allies must be, in hex cells.
@export var range_cells: int = 3


func can_use(caster: BattleUnit) -> bool:
	return not _pick_allies(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for ally in _pick_allies(caster):
		_gift(caster, ally)
	caster.show_float_text("Gift", GIFT_COLOR)


func _gift(caster: BattleUnit, ally: BattleUnit) -> void:
	var held := _held_shards(ally)
	var given: Keepsake = null
	var replacing: Keepsake = null
	if not held.is_empty():
		var own: Keepsake = CombatRng.pick(held)
		var partners := MatchRules.shards().filter(func(s): return MatchRules.combine_result(own, s) != null)
		if not partners.is_empty():
			var shard: Keepsake = CombatRng.pick(partners)
			given = MatchRules.combine_result(own, shard)
			replacing = own
	if given == null:
		if ally.keepsakes.size() >= BattleUnit.MAX_KEEPSAKES:
			return
		given = CombatRng.pick(MatchRules.shards())
	if given == null:
		return
	ally.swap_keepsake_in_combat(given, replacing)
	ally.add_status(TempItemStatus.new(given, replacing))
	KeepsakeVfx.gift_icon(caster.global_position, ally, given)
	ally.show_float_text("+" + given.get_display_name(), GIFT_COLOR)


func _held_shards(unit: BattleUnit) -> Array:
	return unit.keepsakes.filter(func(k): return k.is_shard)


## Allies in range (not him) who can take something: those holding a Shard to combine
## first, then those with a free slot; nearest first within each.
func _pick_allies(caster: BattleUnit) -> Array[BattleUnit]:
	var combiners: Array[BattleUnit] = []
	var others: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive or unit.team != caster.team or unit.is_summon \
				or caster.grid.get_distance(caster.cell, unit.cell) > range_cells:
			continue
		if not _held_shards(unit).is_empty():
			combiners.append(unit)
		elif unit.keepsakes.size() < BattleUnit.MAX_KEEPSAKES:
			others.append(unit)
	var by_distance := func(a, b): return caster.grid.get_distance(caster.cell, a.cell) < caster.grid.get_distance(caster.cell, b.cell)
	combiners.sort_custom(by_distance)
	others.sort_custom(by_distance)
	combiners.append_array(others)
	return combiners.slice(0, targets)


## On an ally holding a temporary item: puts things back as they were once combat ends.
class TempItemStatus extends Status:
	var given: Keepsake
	var replaced: Keepsake   # the Shard it was combined from, or null
	var _undone := false

	func _init(p_given: Keepsake, p_replaced: Keepsake) -> void:
		given = p_given
		replaced = p_replaced

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, _delta: float) -> void:
		if not unit.active:
			_undo(unit)
			unit.remove_status(self)

	func on_removed(unit: BattleUnit) -> void:
		_undo(unit)

	func _undo(unit: BattleUnit) -> void:
		if _undone:
			return
		_undone = true
		if unit.keepsakes.has(given):
			unit.swap_keepsake_in_combat(replaced, given)


const GIFT_COLOR := Color(0.7, 0.9, 1.0)
