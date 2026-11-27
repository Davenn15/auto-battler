class_name ShardGiftGambit
extends Gambit
## Vestibule B: sends temporary Shards to nearby allies. An ally holding a Shard gets one
## that combines with it, and the two become their keepsake on the spot; an ally without one
## gets a random Shard in a free slot. Everything given is taken back when combat ends.
## Allies who can combine are picked first, then the nearest. Each Shard flies to its ally
## as a projectile (GiftShard) and is given when it arrives; it fizzles if the ally dies.
##   B1: one more ally, and allies who can't take a Shard (no Shard to combine, no free slot)
##       become targets after everyone else: their Shard Empowers one of their Keepsakes
##       until combat ends.
## Redundancy (hero Ascension, ExtraVolleyEffect): one more Shard, to one more ally, or if
## there's none, a second one to the nearest ally already gifted.

@export var targets: int = 2
## How close the allies must be, in hex cells.
@export var range_cells: int = 3
## B1: 1 = allies who can't take a Shard can be picked last; theirs Empowers a Keepsake.
@export var can_empower: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return not _pick_allies(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var extra := ExtraVolleyEffect.extra_on(caster)
	var allies := _pick_allies(caster, targets + extra)
	if extra > 0 and allies.size() < targets + extra and not allies.is_empty():
		var nearest: BattleUnit = allies[0]
		for ally in allies:
			if caster.grid.get_distance(caster.cell, ally.cell) < caster.grid.get_distance(caster.cell, nearest.cell):
				nearest = ally
		allies.append(nearest)   # Redundancy's extra Shard doubles up
	var sent := {}
	for ally in allies:
		var delay: float = GiftShard.STAGGER * sent.get(ally, 0)   # a second Shard to one ally lands after the first
		sent[ally] = sent.get(ally, 0) + 1
		GiftShard.fire(caster, ally, delay, can_empower > 0.0)
	caster.show_float_text("Gift", GIFT_COLOR)


## Gives `ally` a temporary Shard from `giver` (combining with one it holds, or into a free
## slot), announced to KeepsakeForge. Returns what it got, or null if it couldn't take one.
## Replication Feed gives a unit Shards this way too. `giver` may be null (it died while
## the Shard was flying); `show_icon` off skips the flying icon (GiftShard flew already).
## `empower` (B1): if it can't take a Shard, the Shard Empowers one of its Keepsakes.
static func gift_to(giver: BattleUnit, ally: BattleUnit, show_icon: bool = true, empower: bool = false) -> Keepsake:
	var held: Array = ally.keepsakes.filter(func(k): return k.is_shard)
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
		if ally.keepsakes.size() >= ally.max_keepsakes():
			if not empower:
				return null
			return _empower(giver, ally)
		given = CombatRng.pick(MatchRules.shards())
	if given == null:
		return null
	ally.swap_keepsake_in_combat(given, replacing)
	ally.add_status(TempItemStatus.new(given, replacing))
	if show_icon and giver != null:
		KeepsakeVfx.gift_icon(giver.global_position, ally, given)
	ally.show_float_text("+" + given.get_display_name(), GIFT_COLOR)
	KeepsakeForge.created_item(giver, given)
	return given


## B1: Empowers a random one of `ally`'s Keepsakes that can still be Empowered, by a random
## one of its two Shard kinds, until combat ends. Returns the Empowered copy, or null.
static func _empower(giver: BattleUnit, ally: BattleUnit) -> Keepsake:
	var options := empowerable(ally)
	if options.is_empty():
		return null
	var original: Keepsake = CombatRng.pick(options)
	var kinds: Array = [original.first_shard, original.second_shard].filter(func(k): return original.empowerment_for(k) != null)
	var copy := original.empowered(CombatRng.pick(kinds))
	if copy == null:
		return null
	ally.swap_keepsake_in_combat(copy, original)
	ally.add_status(TempItemStatus.new(copy, original))
	ally.show_float_text("Empowered " + original.get_display_name(), GIFT_COLOR)
	KeepsakeForge.created_item(giver, Keepsake.shard_of(copy.empowered_with))
	return copy


## `unit`'s Keepsakes a Gift Shard could Empower: not Shards, not already Empowered, and
## not one Gift lent it this combat (so taking things back at the end stays simple).
static func empowerable(unit: BattleUnit) -> Array:
	var lent: Array = []
	for status in unit.statuses:
		if status is TempItemStatus:
			lent.append(status.given)
	return unit.keepsakes.filter(func(k): return not lent.has(k) 			and (k.empowerment_for(k.first_shard) != null or k.empowerment_for(k.second_shard) != null))


func _held_shards(unit: BattleUnit) -> Array:
	return unit.keepsakes.filter(func(k): return k.is_shard)


## Allies in range (not him) who can take something: those holding a Shard to combine
## first, then those with a free slot, then (B1) those with a Keepsake to Empower; nearest
## first within each.
func _pick_allies(caster: BattleUnit, count: int = -1) -> Array[BattleUnit]:
	var combiners: Array[BattleUnit] = []
	var others: Array[BattleUnit] = []
	var empowerables: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive or unit.team != caster.team or unit.is_summon \
				or caster.grid.get_distance(caster.cell, unit.cell) > range_cells:
			continue
		if not _held_shards(unit).is_empty():
			combiners.append(unit)
		elif unit.keepsakes.size() < unit.max_keepsakes():
			others.append(unit)
		elif can_empower > 0.0 and not empowerable(unit).is_empty():
			empowerables.append(unit)
	var by_distance := func(a, b): return caster.grid.get_distance(caster.cell, a.cell) < caster.grid.get_distance(caster.cell, b.cell)
	combiners.sort_custom(by_distance)
	others.sort_custom(by_distance)
	empowerables.sort_custom(by_distance)
	combiners.append_array(others)
	combiners.append_array(empowerables)
	return combiners.slice(0, targets if count < 0 else count)


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


## A Gift Shard in flight: homes in on its ally and gives it the Shard when it arrives
## (ShardGiftGambit.gift_to). Independent of Vestibule, so it still lands if he dies; it
## fizzles if the ally dies first. Drawn in code: a small spinning diamond.
class GiftShard extends Node2D:
	const SPEED := 420.0     # pixels per second
	const STAGGER := 0.15    # seconds between two Shards sent to the same ally
	const LIFT := Vector2(0, -12)
	var caster   # untyped: may be freed
	var ally     # untyped: may be freed
	var empower := false   # B1
	var _delay := 0.0
	var _spin := 0.0

	static func fire(from: BattleUnit, to: BattleUnit, delay: float = 0.0, p_empower: bool = false) -> GiftShard:
		var shard := GiftShard.new()
		shard.empower = p_empower
		shard.caster = from
		shard.ally = to
		shard._delay = delay
		shard.z_index = 15
		shard.visible = delay <= 0.0
		from.get_parent().add_child(shard)
		shard.global_position = from.global_position + LIFT
		return shard

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(ally) or not ally.alive or not ally.is_inside_tree():
			queue_free()
			return
		if _delay > 0.0:
			_delay -= delta
			visible = _delay <= 0.0
			if is_instance_valid(caster):
				global_position = caster.global_position + LIFT
			return
		var to: Vector2 = ally.global_position + LIFT - global_position
		var step := SPEED * delta
		_spin += delta * 9.0
		queue_redraw()
		if to.length() <= step:
			var giver: BattleUnit = caster if is_instance_valid(caster) else null
			ShardGiftGambit.gift_to(giver, ally, false, empower)
			queue_free()
			return
		global_position += to.normalized() * step

	func _draw() -> void:
		if not KeepsakeVfx.enabled():
			return
		var points := PackedVector2Array()
		for i in 4:
			var a := _spin + TAU * i / 4.0
			points.append(Vector2(cos(a), sin(a)) * (7.0 if i % 2 == 0 else 4.0))
		draw_circle(Vector2.ZERO, 9.0, Color(ShardGiftGambit.GIFT_COLOR, 0.3))
		draw_colored_polygon(points, ShardGiftGambit.GIFT_COLOR)
		points.append(points[0])
		draw_polyline(points, Color.WHITE, 1.0, true)
