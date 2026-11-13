class_name Upgrade
extends Resource
## One node in a unit's upgrade tree. The first upgrade picks one of UnitData.upgrades;
## the second picks one of that upgrade's next_choices. Like Passives and Gambits, these
## are shared settings, so no battle state goes here.

@export var upgrade_name: String = "Upgrade"
@export_multiline var description: String = ""
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
