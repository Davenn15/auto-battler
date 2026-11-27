class_name Upgrade
extends Resource
## One node in a unit's upgrade tree. The first upgrade picks one of UnitData.upgrades;
## the second picks one of that upgrade's next_choices. Like Passives and Gambits, these
## are shared settings, so no battle state goes here.

@export var upgrade_name: String = "Upgrade"
@export_multiline var description: String = ""
## Shown in italics before the unit's name once this upgrade is taken ("Mystical Bremes").
## Paths (the first upgrades) use their Upgrade Name instead; set this on the later ones.
@export var adjective: String = ""
## Passives this upgrade adds to the unit. New mechanics go here.
@export var passives: Array[Passive] = []
## If set, replaces the unit's Gambit (a stronger version, or a different one entirely).
@export var gambit: Gambit
## The choices offered at the next upgrade if this one was picked. Empty on the last level.
@export var next_choices: Array[Upgrade] = []

## Numbers added to the unit's current Gambit, by property name, e.g. "attack_count": 2.
## Use this to make the Gambit stronger without copying it. Set `gambit` only when the
## upgrade switches to a different kind of Gambit.
@export var gambit_bonuses: Dictionary[String, float] = {}

## Gambit properties set to a new value, by name. Use this for changes that aren't
## "more", like damage_type (0 = Might, 1 = Insight, 2 = Celerity).
@export var gambit_overrides: Dictionary[String, float] = {}

## Extra attack range, in hex cells, while this upgrade is chosen.
@export var attack_range_bonus: int = 0

## Where computer-run armies place the unit while this upgrade is chosen (see
## UnitData.placement). Inherit keeps what it had before this upgrade: the level 1
## upgrade's choice for a level 2 upgrade, otherwise the unit's own Placement.
enum Placement { INHERIT, FRONT, SECOND_ROW, BACK, RANGED }
@export var placement: Placement = Placement.INHERIT


## True if the upgrade gives or changes the Gambit (its numbers then get Gambit-only boosts).
static func touches_gambit(upgrade: Upgrade) -> bool:
	return upgrade.gambit != null or not upgrade.gambit_bonuses.is_empty() or not upgrade.gambit_overrides.is_empty()


## The upgrades along `path` (choice indices, from the unit's first upgrades), in order.
static func along(data: UnitData, path: Array) -> Array[Upgrade]:
	var chosen: Array[Upgrade] = []
	var choices := data.upgrades if data != null else ([] as Array[Upgrade])
	for index in path:
		if index < 0 or index >= choices.size():
			break
		chosen.append(choices[index])
		choices = choices[index].next_choices
	return chosen


## The unit's Gambit once `chosen` (upgrades, in order) are taken: the last new Gambit
## among them (or the unit's own), with the Gambit bonuses and overrides that came after
## it applied. The shared file never changes: a changed Gambit is a copy.
static func gambit_after(data: UnitData, chosen: Array) -> Gambit:
	var result: Gambit = data.gambit if data != null else null
	var bonuses := {}
	var overrides := {}
	for upgrade in chosen:
		if upgrade.gambit != null:
			result = upgrade.gambit
			bonuses.clear()   # earlier bonuses were for the old Gambit
			overrides.clear()
		for property in upgrade.gambit_bonuses:
			bonuses[property] = bonuses.get(property, 0.0) + upgrade.gambit_bonuses[property]
		overrides.merge(upgrade.gambit_overrides, true)
	if result == null or (bonuses.is_empty() and overrides.is_empty()):
		return result
	return changed_gambit(result, bonuses, overrides)


## A copy of `base` with `bonuses` added to and `overrides` set on its properties.
static func changed_gambit(base: Gambit, bonuses: Dictionary, overrides: Dictionary) -> Gambit:
	var copy := base.duplicate() as Gambit
	for property in bonuses:
		if property in copy:
			var current = copy.get(property)
			copy.set(property, current + type_convert(bonuses[property], typeof(current)))
		else:
			push_warning("Upgrade changes unknown Gambit property '%s'." % property)
	for property in overrides:
		if property in copy:
			copy.set(property, type_convert(overrides[property], typeof(copy.get(property))))
		else:
			push_warning("Upgrade sets unknown Gambit property '%s'." % property)
	return copy
