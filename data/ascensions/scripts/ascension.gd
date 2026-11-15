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
## For a standalone Ascension: the lower-tier one this is an empowered version of (e.g.
## Celerity IV empowers Celerity III). Versions form a family: once you own one, the others
## are never offered. Not needed inside an AscensionFamily, which links its versions itself.
@export var empowers: Ascension
## Leave empty for the whole army. Otherwise only these units get the stats and effect,
## and the Ascension is offered more often to players who own one of them (and rarely to
## those who don't; see MatchRules.ascension_weight). For a One chosen unit Ascension,
## only these units can be picked.
@export var affected_units: Array[UnitData] = []

@export_group("Stats for every affected unit")
@export var might: float = 0.0
@export var might_ward: float = 0.0
@export var celerity: float = 0.0
@export var celerity_ward: float = 0.0
@export var insight: float = 0.0
@export var insight_ward: float = 0.0
@export var health: float = 0.0

@export_group("Effect")
## Run on every affected unit at battle start, like a Keepsake's effect.
@export var effect: Passive

## Set when loaded (see MatchRules.ascension_pool), not in the editor:
## the AscensionFamily this is a version of, if any.
var family: AscensionFamily
## How it's named when saved or sent with an army: its file path, or for a family version
## "<family file path>#<index in versions>".
var key: String = ""

const NUMERALS := ["", "I", "II", "III", "IV"]


## True if `data`'s units get this Ascension (always, for an army-wide one). A chosen-unit
## Ascension is only ever given to its chosen unit, so it always applies there.
func applies_to(data: UnitData) -> bool:
	return is_chosen() or affected_units.is_empty() or affected_units.has(data)


## True for an Ascension the player gives to one unit they pick.
func is_chosen() -> bool:
	return target == Target.CHOSEN_UNIT


## True if `unit` may be picked for this (chosen-unit) Ascension.
func can_pick(unit: ArmyUnit) -> bool:
	if unit == null or unit.data == null:
		return false
	if not allowed_tiers.is_empty() and not allowed_tiers.has(unit.data.tier):
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
	}


## Adds one Ascension's stats to a unit for the battle.
class StatsStatus extends Status:
	var ascension: Ascension

	func _init(p_ascension: Ascension) -> void:
		ascension = p_ascension

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + ascension.get_stat_bonuses().get(stat, 0.0)
