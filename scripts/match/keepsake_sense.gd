class_name KeepsakeSense
extends RefCounted
## The computer player's sense of which keepsakes suit which units. Two opinions, blended:
##   1. From the data: how much a keepsake's stats would grow the unit's damage (attacks,
##      plus Gambits that scale with an attribute) and its toughness (health and wards,
##      counted more for units that stand in front). It knows nothing about special effects.
##   2. From the sims (KeepsakeLiftTable): how much more often the unit's team actually won
##      when it carried that keepsake. The more battles a pair was seen in, the more this
##      counts, but the data opinion always keeps a share so upgrade paths still matter.
## Scores are on a shared scale: 0 is an ordinary pairing, +1 a clearly good one, -1 a
## clearly poor one.

const LIFT_TABLE_PATH := "res://data/ai/keepsake_lift.tres"
## Share of the score that always comes from the data, however many battles the sims saw.
const DATA_SHARE_MIN := 0.25

# Rough battle model behind the data opinion. Only the ratios matter.
## Enemies a Gambit typically hits.
const CAST_TARGETS := 2.0
## Damage a Gambit does before its attribute scaling.
const CAST_FLAT := 80.0
## Charge a unit gains per second from being hit, roughly.
const CHARGE_FROM_HITS := 3.0
## Seconds of fighting, for turning Vampirism into health.
const BATTLE_SECONDS := 20.0

static var _table: KeepsakeLiftTable
static var _table_loaded := false
static var _data_mean := 0.0
static var _data_spread := 0.0   # 0 until measured
static var _profiles := {}       # "unit path|0,1" -> profile dictionary
static var _scores := {}         # remembered scores, by keepsake, unit, path and what it carries


## How well `keepsake` suits `unit` (an ArmyUnit), counting what it already carries.
static func score_for(keepsake: Keepsake, unit: ArmyUnit) -> float:
	return score(keepsake, unit.data, unit.path, unit.items)


## How well `keepsake` suits a unit with this data and upgrade path.
static func score(keepsake: Keepsake, data: UnitData, path: Array, carried: Array = []) -> float:
	var key := "%d|%d|%s|%s" % [keepsake.get_instance_id(), data.get_instance_id(), str(path),
			str(carried.map(func(k): return k.get_instance_id()))]
	if not _scores.has(key):
		_scores[key] = _score(keepsake, data, path, carried)
	return _scores[key]


static func _score(keepsake: Keepsake, data: UnitData, path: Array, carried: Array) -> float:
	_measure()
	var from_data := (data_score(keepsake, data, path, carried) - _data_mean) / _data_spread
	var table := lift_table()
	if table == null:
		return from_data
	var entry: Array = table.get_lift(data.display_name.capitalize(), keepsake.get_display_name())
	if int(entry[1]) <= 0:
		return from_data
	# The sims' average counts as far as it's reliable (more battles, more trust).
	var trust := minf(float(entry[2]), 1.0 - DATA_SHARE_MIN)
	var from_sims := float(entry[3]) / maxf(table.spread, 0.001)
	return lerpf(from_data, from_sims, trust)


## The best score `keepsake` gets on any of `units` that still has a free slot, or -INF.
static func best_score(keepsake: Keepsake, units: Array) -> float:
	var best := -INF
	for unit in units:
		if unit.items.size() < BattleUnit.MAX_KEEPSAKES:
			best = maxf(best, score_for(keepsake, unit))
	return best


## Picks one of `options` at random, weighted by exp(strength x score). `scores` lines up
## with `options`. strength 0 = no preference; higher = sticks closer to the best.
static func weighted_pick(options: Array, scores: Array, strength: float) -> int:
	if options.is_empty():
		return -1
	var top: float = scores.max()
	var weights: Array[float] = []
	var total := 0.0
	for s in scores:
		var w := exp(strength * (float(s) - top))   # minus the top keeps exp from overflowing
		weights.append(w)
		total += w
	var roll := randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


static func lift_table() -> KeepsakeLiftTable:
	if not _table_loaded:
		_table_loaded = true
		if ResourceLoader.exists(LIFT_TABLE_PATH):
			_table = load(LIFT_TABLE_PATH) as KeepsakeLiftTable
	return _table


# ---------- The data opinion ----------

## How much the keepsake grows the unit, as a share: 0.1 = about 10% better. Damage and
## toughness gains are added, toughness weighted by how exposed the unit stands.
static func data_score(keepsake: Keepsake, data: UnitData, path: Array, carried: Array = []) -> float:
	var p := _profile(data, path)
	var before := _stats_with(p, carried)
	var with_it: Array = carried.duplicate()
	with_it.append(keepsake)
	var after := _stats_with(p, with_it)
	var offense_before := _offense(p, before)
	var offense_gain := _offense(p, after) / offense_before - 1.0 if offense_before > 0.0 else 0.0
	var toughness_gain := _toughness(p, after) / _toughness(p, before) - 1.0
	return offense_gain + p["exposure"] * toughness_gain


## Mean and spread of data_score over every unit and item, so it can be put on the same
## scale as the sim lift. Measured once.
static func _measure() -> void:
	if _data_spread > 0.0:
		return
	var values: Array[float] = []
	var items: Array = MatchRules.keepsakes() + MatchRules.shards()
	for data in MatchRules.roster():
		for item in items:
			values.append(data_score(item, data, []))
	if values.is_empty():
		_data_spread = 1.0
		return
	var total := 0.0
	for v in values:
		total += v
	_data_mean = total / values.size()
	var square := 0.0
	for v in values:
		square += (v - _data_mean) * (v - _data_mean)
	_data_spread = maxf(sqrt(square / values.size()), 0.001)


## What the data says about a unit on a path: its stats, how its Gambit scales, how often
## it casts and how exposed it stands.
static func _profile(data: UnitData, path: Array) -> Dictionary:
	var key := "%s|%s" % [data.resource_path, ",".join(PackedStringArray(path.map(func(i): return str(i))))]
	if _profiles.has(key):
		return _profiles[key]
	var chosen: Array[Upgrade] = []
	var choices := data.upgrades
	for index in path:
		if index < 0 or index >= choices.size():
			break
		chosen.append(choices[index])
		choices = choices[index].next_choices
	var level := chosen.size()
	var stats := {}
	for stat in Stats.Stat.values():
		stats[stat] = data.get_base_stat(stat) * Stats.upgrade_multiplier(stat, level) * Stats.tier_multiplier(stat, data.tier)
	stats["health"] = data.max_health * Stats.upgrade_health_multiplier(level) * Stats.tier_health_multiplier(data.tier)
	# Which attributes the Gambit and passives scale with, by property name (might_scaling ...).
	var gambit := data.gambit
	var bonuses := {}
	var passives: Array = data.passives.duplicate()
	var reach := data.attack_range_cells
	for upgrade in chosen:
		passives.append_array(upgrade.passives)
		reach += upgrade.attack_range_bonus
		if upgrade.gambit != null:
			gambit = upgrade.gambit
			bonuses.clear()
		for property in upgrade.gambit_bonuses:
			bonuses[property] = bonuses.get(property, 0.0) + upgrade.gambit_bonuses[property]
	var scaling := {Stats.Stat.MIGHT: 0.0, Stats.Stat.INSIGHT: 0.0, Stats.Stat.CELERITY: 0.0}
	if gambit != null:
		_add_scaling(gambit, scaling, bonuses)
	for passive in passives:
		if passive != null:
			_add_scaling(passive, scaling, {})
	var exposure := 0.4
	var row := RandomTeams.row_of({"data": data, "path": path})
	if row == UnitData.Placement.BACK:
		exposure = 0.3
	elif row == UnitData.Placement.FRONT or reach <= 1:
		exposure = 1.0
	elif reach == 2:
		exposure = 0.75
	elif reach == 3:
		exposure = 0.55
	var profile := {
		"stats": stats, "scaling": scaling, "exposure": exposure,
		"casts": gambit != null and data.max_charge > 0.0,
		"max_charge": maxf(data.max_charge, 1.0), "charge_on_attack": data.charge_on_attack,
		"charge_regen": data.charge_regen,
	}
	_profiles[key] = profile
	return profile


## Adds up a resource's float properties named like "might_scaling" or "pop_insight_scaling".
static func _add_scaling(source: Resource, scaling: Dictionary, bonuses: Dictionary) -> void:
	for property in source.get_property_list():
		if not (property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or property["type"] != TYPE_FLOAT:
			continue
		var prop_name: String = property["name"]
		if not prop_name.ends_with("scaling"):
			continue
		var amount := float(source.get(prop_name)) + float(bonuses.get(prop_name, 0.0))
		if prop_name.contains("might"):
			scaling[Stats.Stat.MIGHT] += amount
		elif prop_name.contains("insight"):
			scaling[Stats.Stat.INSIGHT] += amount
		elif prop_name.contains("celerity"):
			scaling[Stats.Stat.CELERITY] += amount


## The profile's stats plus every item's stat bonuses and health.
static func _stats_with(p: Dictionary, items: Array) -> Dictionary:
	var stats: Dictionary = p["stats"].duplicate()
	for item in items:
		var keepsake := item as Keepsake
		if keepsake == null:
			continue
		var bonuses := keepsake.get_stat_bonuses()
		for stat in bonuses:
			stats[stat] = stats.get(stat, 0.0) + bonuses[stat]
		stats["health"] += keepsake.health
	return stats


## Damage per second, roughly: basic attacks (Might, sped by Celerity, boosted by wrack)
## plus Gambit casts (charge from attacks and hits, plus Charge Regen; Insight speeds it up).
static func _offense(p: Dictionary, s: Dictionary) -> float:
	var attacks := maxf(s[Stats.Stat.CELERITY], 1.0) / Stats.ATTRIBUTE_BASELINE / Stats.BASE_ATTACK_COOLDOWN
	var wrack: float = clampf(s[Stats.Stat.WRACK_CHANCE], 0.0, Stats.MAX_WRACK_LEVEL) * s[Stats.Stat.WRACK_DAMAGE]
	var damage: float = s[Stats.Stat.MIGHT] * (1.0 + wrack) * attacks
	if p["casts"]:
		var charge: float = (p["charge_on_attack"] * attacks + CHARGE_FROM_HITS) * Stats.charge_multiplier(s[Stats.Stat.INSIGHT]) \
				+ Stats.charge_regen(p["charge_regen"], s[Stats.Stat.INSIGHT])
		var scaling: Dictionary = p["scaling"]
		var per_cast := CAST_FLAT
		for stat in scaling:
			per_cast += scaling[stat] * s[stat]
		damage += charge / p["max_charge"] * CAST_TARGETS * per_cast
	return damage


## Effective health: health (plus what Vampirism heals) through the average ward.
static func _toughness(p: Dictionary, s: Dictionary) -> float:
	var health: float = s["health"] + s.get(Stats.Stat.VAMPIRISM, 0.0) * _offense(p, s) * BATTLE_SECONDS
	var through := (Stats.ward_multiplier(s[Stats.Stat.MIGHT_WARD]) + Stats.ward_multiplier(s[Stats.Stat.INSIGHT_WARD]) \
			+ Stats.ward_multiplier(s[Stats.Stat.CELERITY_WARD])) / 3.0
	return health / through
