class_name Ascension
extends Resource
## An army powerup picked at an Encounter. It lasts the whole match and applies to every
## unit in the army at the start of each fight: a block of stats, plus optionally an effect
## (a Passive every unit runs at battle start).
##
## Which pool it's in comes from its folder: data/ascensions/neutral/ for Neutral
## Ascensions, data/ascensions/<faction folder>/ (as in data/units/) for Faction ones. The
## "tier N" folders inside are just for tidiness; `tier` decides the tier.
##
## Each type's Encounters go up a tier each time: the 1st Faction Encounter offers tier 1
## Faction Ascensions, the 2nd tier 2, up to tier 4 (then that type has no more Encounters).
## Shared settings, like Keepsakes: nothing here changes in battle.
##
## An Ascension with several tiers is easiest kept as an AscensionFamily: one file holding
## every tier. A standalone one can instead name its lower version in `empowers`.

@export var ascension_name: String = ""
@export_multiline var description: String = ""
## 1-4. Offered only at Encounters of this tier.
@export_range(1, 4) var tier: int = 1
enum Target { ARMY, CHOSEN_UNIT }
## Army: every (affected) unit gets it. One chosen unit: after taking it, the player picks
## one of their units, and only that unit gets it, for the rest of the match.
@export var target: Target = Target.ARMY
## One chosen unit only: the tiers the pick is limited to (e.g. [1, 2]). Empty = any tier.
## Affected Units, if set, limits the pick to those units too. An Ascension none of your
## units could take is never offered.
@export var allowed_tiers: Array[int] = []
## One chosen unit only: only fully upgraded units can be picked.
@export var requires_max_level := false
## One chosen unit only: only units that have a Gambit can be picked.
@export var requires_gambit := false
## For a standalone Ascension: the lower-tier one this is an empowered version of (e.g.
## Celerity IV empowers Celerity III). Versions form a family: once you own one, the others
## are never offered. Not needed inside an AscensionFamily, which links its versions itself.
@export var empowers: Ascension
## Leave empty for the whole army. Otherwise only these units get the stats and effect,
## and the Ascension is offered more often to players who own one of them (and rarely to
## those who don't; see MatchRules.ascension_weight). For a One chosen unit Ascension,
## only these units can be picked.
@export var affected_units: Array[UnitData] = []
## For a Beam Ascension: offered more often to players with a unit that has a Beam (see
## Beam.has_beam), and rarely to those without, like Affected Units does for units.
@export var favors_beams := false
## With Affected Units: the Ascension is for having all of them (e.g. a pair). Offered 3x
## as often when you own all of them, normally when you own some, and rarely with none.
@export var needs_all_affected := false
## For a unit-specific one: the first upgrade a unit must take to benefit (0 = A, 1 = B),
## e.g. Perfect Reflection needs Bremes' B (Mirror Image). -1 = any path.
@export var required_branch: int = -1

@export_group("Stats for every affected unit")
@export var might: float = 0.0
@export var might_ward: float = 0.0
@export var celerity: float = 0.0
@export var celerity_ward: float = 0.0
@export var insight: float = 0.0
@export var insight_ward: float = 0.0
@export var health: float = 0.0
## 0.15 = +15% Wrack chance.
@export var wrack_chance: float = 0.0
## 0.1 = +10% Wrack Damage (each Wrack level multiplies damage by 1 + Wrack Damage).
@export var wrack_damage: float = 0.0
## 0.15 = +15% chance to dodge attacks.
@export var dodge_chance: float = 0.0

## Extra Keepsake slots every affected unit gets (a chosen-unit one: its chosen unit).
@export var keepsake_slots: int = 0
## Extra empowered Keepsakes every affected unit may carry (Keepsake Empowering; one is usual).
@export var empowered_keepsakes: int = 0
## Random Shards the player gets in their inventory when they take this Ascension.
@export var random_shards: int = 0

@export_group("Effect")
## Run on every affected unit at battle start, like a Keepsake's effect.
@export var effect: Passive
## One chosen unit only: the unit also gains the other final upgrade of its path (A1 also
## gets A2), and its stats grow one level more. Only units with a second final upgrade
## can be picked.
@export var grants_other_final_upgrade := false

## Set when loaded (see MatchRules.ascension_pool), not in the editor:
## the AscensionFamily this is a version of, if any.
var family: AscensionFamily
## How it's named when saved or sent with an army: its file path, or for a family version
## "<family file path>#<index in versions>".
var key: String = ""

const NUMERALS := ["", "I", "II", "III", "IV"]


## The Encounter tiers this can be offered at. Most: just its Tier. Unit-specific ones
## (Affected Units) go by their unit's tier instead, the highest one for a pair: tier 1
## and 2 units at tier 1-2 Encounters, tier 3 units at 2-3, tier 4 units at 3-4.
func encounter_tiers() -> Array[int]:
	var result: Array[int] = []
	if affected_units.is_empty():
		result.append(tier)
		return result
	var unit_tier := 1
	for data in affected_units:
		if data != null:
			unit_tier = maxi(unit_tier, data.tier)
	if unit_tier <= 2:
		result.assign([1, 2])
	else:
		result.assign([unit_tier - 1, unit_tier])
	return result


func offered_at(encounter_tier: int) -> bool:
	return encounter_tiers().has(encounter_tier)


## "2", or "1-2" for one offered at two tiers. `roman` uses numerals (I-II).
func tier_text(roman := false) -> String:
	var tiers := encounter_tiers()
	var names: Array = tiers.map(func(t): return NUMERALS[clampi(t, 0, 4)] if roman else str(t))
	return "–".join(names)



# ---------- Who can benefit (so players aren't offered ones they can't use) ----------

## True if this Ascension only helps certain units (Affected Units, a Beam, a branch).
func has_unit_requirement() -> bool:
	return not affected_units.is_empty() or favors_beams or required_branch >= 0


## True if a unit of `data` on exactly upgrade `path` gets something from this Ascension.
func satisfied_by(data: UnitData, path: Array) -> bool:
	if not affected_units.is_empty() and not affected_units.has(data):
		return false
	if required_branch >= 0 and (path.is_empty() or path[0] != required_branch):
		return false
	if favors_beams and not Beam.has_beam(data, path):
		return false
	return true


## The fewest upgrades a unit of `data`, now on `path`, needs in total to benefit (its
## current level if it already does), or -1 if no path from where it is gets there.
func level_to_benefit(data: UnitData, path: Array) -> int:
	if data == null:
		return -1
	var levels := RandomTeams.paths_by_level(data)
	for level in range(path.size(), levels.size()):
		for candidate in levels[level]:
			if candidate.slice(0, path.size()) == path and satisfied_by(data, candidate):
				return level
	return -1


## True if a unit of `data` on upgrade `path` has a Gambit (its own, or one an upgrade gives).
static func has_gambit(data: UnitData, path: Array) -> bool:
	if data.gambit != null:
		return true
	var choices := data.upgrades
	for pick in path:
		if pick < 0 or pick >= choices.size():
			break
		if choices[pick].gambit != null:
			return true
		choices = choices[pick].next_choices
	return false


## True if `data`'s units get this Ascension (always, for an army-wide one). A chosen-unit
## Ascension is only ever given to its chosen unit, so it always applies there.
func applies_to(data: UnitData) -> bool:
	return is_chosen() or affected_units.is_empty() or affected_units.has(data)


## True for an Ascension the player gives to one unit they pick.
func is_chosen() -> bool:
	return target == Target.CHOSEN_UNIT


## True for an Ascension from the Neutral pool (otherwise it's from a faction's).
func is_neutral() -> bool:
	return (key if key != "" else resource_path).contains("/neutral/")


## The faction whose pool this comes from ("Sword Court"), or "" for a Neutral one.
func faction_name() -> String:
	if is_neutral():
		return ""
	var path := (key if key != "" else resource_path).trim_prefix(MatchRules.ASCENSIONS_DIR + "/")
	return MatchRules.faction_name(path.get_slice("/", 0))


## True if `unit` may be picked for this (chosen-unit) Ascension.
func can_pick(unit: ArmyUnit) -> bool:
	if unit == null or unit.data == null:
		return false
	if not allowed_tiers.is_empty() and not allowed_tiers.has(unit.data.tier):
		return false
	if (requires_max_level or grants_other_final_upgrade) and not unit.is_maxed():
		return false
	if requires_gambit and not Ascension.has_gambit(unit.data, unit.path):
		return false
	if grants_other_final_upgrade and BattleUnit.other_final_upgrades(unit.data, unit.path).is_empty():
		return false
	return affected_units.is_empty() or affected_units.has(unit.data)


## "Column, Merribold" for a unit-specific Ascension; "" for an army-wide one.
func affected_names() -> String:
	return ", ".join(affected_units.filter(func(d): return d != null).map(func(d): return d.display_name.capitalize()))


## The lowest version this is an empowered version of (itself if it empowers nothing).
func family_root() -> Resource:
	if family != null:
		return family
	var root: Ascension = self
	for i in 8:   # a guard against a loop of empowers links
		if root.empowers == null:
			break
		root = root.empowers
	return root


## True if `other` is this Ascension or another version of it.
func same_family(other: Ascension) -> bool:
	return other != null and family_root() == other.family_root()


func get_display_name() -> String:
	if ascension_name != "":
		return ascension_name
	if family != null:
		return ("%s %s" % [family.family_name, NUMERALS[clampi(tier, 0, 4)]]).strip_edges()
	return resource_path.get_file().get_basename().capitalize()


## The name it's saved and sent under (see `key`).
func get_key() -> String:
	return key if key != "" else resource_path


## The stats this Ascension adds to each unit, as {Stats.Stat: amount}.
func get_stat_bonuses() -> Dictionary:
	return {
		Stats.Stat.MIGHT: might, Stats.Stat.MIGHT_WARD: might_ward,
		Stats.Stat.CELERITY: celerity, Stats.Stat.CELERITY_WARD: celerity_ward,
		Stats.Stat.INSIGHT: insight, Stats.Stat.INSIGHT_WARD: insight_ward,
		Stats.Stat.WRACK_CHANCE: wrack_chance, Stats.Stat.WRACK_DAMAGE: wrack_damage,
	}


## Adds one Ascension's stats to a unit for the battle.
class StatsStatus extends Status:
	var ascension: Ascension

	func _init(p_ascension: Ascension) -> void:
		ascension = p_ascension

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + ascension.get_stat_bonuses().get(stat, 0.0)

	func modify_dodge_chance(_unit: BattleUnit, chance: float) -> float:
		return chance + ascension.dodge_chance


## Where this Ascension's description placeholders get their numbers: its effect, then
## itself (its stats, Keepsake slots...). Add a unit's stats with with_unit for current numbers.
func description_context() -> DescriptionContext:
	var ctx := DescriptionContext.new()
	if effect != null:
		ctx.sources.append(effect)
		ctx.named["effect"] = effect
	ctx.sources.append(self)
	return ctx
