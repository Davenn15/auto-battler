class_name DescriptionContext
extends RefCounted
## Where a description's number placeholders get their values (see Keyphrases.format).
## A placeholder like {damage} is looked up on each source in turn; one that starts with a
## name, like {gambit.damage} or {passive.duration}, looks only at that named source.

var sources: Array = []
var named: Dictionary = {}

## The unit's stats the description's current numbers are worked out from (Stats.Stat ->
## value), its max health, and (when there's one on the board) the unit itself, whose
## statuses give heal, shield and duration boosts. Empty / 0 / null: no unit, so the
## description shows base numbers and scalings only.
var stats: Dictionary = {}
var max_health := 0.0
var unit: BattleUnit = null
## The description is of the unit's Gambit (Gambit-only boosts apply).
var from_gambit := false

const SCALING_STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY]


static func of(source: Object) -> DescriptionContext:
	var ctx := DescriptionContext.new()
	if source != null:
		ctx.sources.append(source)
	return ctx


## Current numbers from `battle_unit`'s start-of-combat stats (and its boosts).
func with_unit(battle_unit: BattleUnit, gambit := false) -> DescriptionContext:
	if battle_unit == null:
		return self
	unit = battle_unit
	from_gambit = gambit
	for stat in SCALING_STATS:
		stats[stat] = battle_unit.description_stat(stat)
	max_health = battle_unit.description_max_health()
	return self


## Current numbers from a unit's own stats at `level` upgrades and `buffs` (no Keepsakes,
## Ascensions or other gains): for units that aren't on the board (the shop).
func with_base_stats(data: UnitData, level: int, buffs: int = 0, gambit := false) -> DescriptionContext:
	if data == null:
		return self
	from_gambit = gambit
	for stat in SCALING_STATS:
		stats[stat] = data.get_base_stat(stat) * Stats.upgrade_multiplier(stat, level) \
				* Stats.tier_multiplier(stat, data.tier) * Stats.buff_multiplier(stat, buffs)
	max_health = data.max_health * Stats.upgrade_health_multiplier(level) \
			* Stats.tier_health_multiplier(data.tier) * Stats.buff_health_multiplier(buffs)
	return self


## Current numbers for an upgrade `battle_unit` hasn't taken (at `level`): its current
## stats, plus what that many upgrade levels would add to its base stats and health.
func with_unit_at_level(battle_unit: BattleUnit, level: int, gambit := false) -> DescriptionContext:
	with_unit(battle_unit, gambit)
	if battle_unit == null or battle_unit.data == null:
		return self
	var data := battle_unit.data
	var now := battle_unit.upgrade_path.size()
	for stat in SCALING_STATS:
		stats[stat] += data.get_base_stat(stat) * Stats.tier_multiplier(stat, data.tier) \
				* Stats.buff_multiplier(stat, battle_unit.buffs) \
				* (Stats.upgrade_multiplier(stat, level) - Stats.upgrade_multiplier(stat, now))
	max_health += data.max_health * Stats.tier_health_multiplier(data.tier) * Stats.buff_health_multiplier(battle_unit.buffs) \
			* (Stats.upgrade_health_multiplier(level) - Stats.upgrade_health_multiplier(now))
	return self


func has_stats() -> bool:
	return not stats.is_empty()


## The unit's boosts to a heal (`is_shield` false) or shield it gives, one per source: an
## Array of [multiplier, source] (source: the Keepsake giving it, or null). Empty: none.
func support_boosts(is_shield: bool) -> Array:
	return _boosts(func(status): return status.modify_outgoing_support(unit, unit, 100.0, is_shield, from_gambit) / 100.0)


## The unit's boosts to how long the shields it gives last, one per source.
func shield_time_boosts() -> Array:
	return _boosts(func(status): return status.modify_support_duration(unit, unit, 100.0, from_gambit) / 100.0)


## The unit's boosts to how long its crowd control and debuffs last, one per source.
func control_boosts() -> Array:
	return _boosts(func(status): return status.modify_control_power(unit, 1.0))


## Each of the unit's statuses' multiplier from `measure`, with the Keepsake it came from.
func _boosts(measure: Callable) -> Array:
	var out: Array = []
	if unit == null or not is_instance_valid(unit):
		return out
	var by_status := unit.status_sources()
	for status in unit.statuses:
		var multiplier: float = measure.call(status)
		if not is_equal_approx(multiplier, 1.0):
			out.append([multiplier, by_status.get(status)])
	return out


## For an upgrade on `path` (choice indices from the unit's first upgrades): the upgrade
## itself, its new passives, and the unit's Gambit as it is once that upgrade is taken
## (its own new Gambit, or the older one with every bonus up to here), so its numbers are
## the new totals.
static func for_upgrade(data: UnitData, path: Array) -> DescriptionContext:
	var ctx := DescriptionContext.new()
	if data == null:
		return ctx
	var chosen := Upgrade.along(data, path)
	if chosen.is_empty():
		return ctx
	var upgrade: Upgrade = chosen[-1]
	ctx.sources.append(upgrade)
	for passive in upgrade.passives:
		ctx.sources.append(passive)
	if not upgrade.passives.is_empty():
		ctx.named["passive"] = upgrade.passives[0]
	var gambit := Upgrade.gambit_after(data, chosen)
	if gambit != null:
		ctx.sources.append(gambit)
		ctx.named["gambit"] = gambit
	return ctx


## The value at `path` ("damage", "gambit.damage", "status.duration"), or null.
func lookup(path: String) -> Variant:
	var parts := path.split(".")
	var candidates: Array = sources
	if parts.size() > 1 and named.has(parts[0]):
		candidates = [named[parts[0]]]
		parts = parts.slice(1)
	for source in candidates:
		var value: Variant = _walk(source, parts)
		if value != null:
			return value
	return null


static func _walk(source: Variant, parts: PackedStringArray) -> Variant:
	var at: Variant = source
	for part in parts:
		if at is Object and part in at:
			at = at.get(part)
		else:
			return null
	return at if (at is float or at is int) else null
