class_name Stats
extends RefCounted
## One place for the attribute / damage type / ward definitions and the formulas that
## use them. Tweaking balance or renaming things should only need edits in this file.

## Every stat a unit has. Add new ones here (and in UnitData.get_base_stat).
enum Stat { MIGHT, INSIGHT, CELERITY, MIGHT_WARD, INSIGHT_WARD, CELERITY_WARD, WRACK_CHANCE, WRACK_DAMAGE }

## The three kinds of damage. The order matches the "Might / Insight / Celerity" dropdown
## on UnitData and Gambits, so keep them in sync if you reorder or rename.
enum DamageType { MIGHT, INSIGHT, CELERITY }

## Display names, for any UI that shows stats or damage types.
const STAT_NAMES := {
	Stat.MIGHT: "Might",
	Stat.INSIGHT: "Insight",
	Stat.CELERITY: "Celerity",
	Stat.MIGHT_WARD: "Might Ward",
	Stat.INSIGHT_WARD: "Insight Ward",
	Stat.CELERITY_WARD: "Celerity Ward",
	Stat.WRACK_CHANCE: "Wrack Chance",
	Stat.WRACK_DAMAGE: "Wrack Damage",
}

const DAMAGE_TYPE_NAMES := {
	DamageType.MIGHT: "Might",
	DamageType.INSIGHT: "Insight",
	DamageType.CELERITY: "Celerity",
}

## Damage number color for each damage type. Kept a little below full brightness so
## wracks have room to be brighter.
const DAMAGE_TYPE_COLORS := {
	DamageType.MIGHT: Color(0.9, 0.2, 0.2),       # red
	DamageType.INSIGHT: Color(0.3, 0.5, 1.0),     # blue
	DamageType.CELERITY: Color(0.95, 0.8, 0.15),  # yellow
}
## How far a wrack's number is lightened toward white (0 = no change, 1 = pure white).
const WRACK_BRIGHTEN := 0.45


## The color to show damage of this type in, brighter if it was a wrack.
static func damage_color(damage_type: int, is_wrack: bool = false) -> Color:
	var color: Color = DAMAGE_TYPE_COLORS.get(damage_type, Color.WHITE)
	return color.lightened(WRACK_BRIGHTEN) if is_wrack else color

## Which ward reduces which damage type.
const WARD_FOR_TYPE := {
	DamageType.MIGHT: Stat.MIGHT_WARD,
	DamageType.INSIGHT: Stat.INSIGHT_WARD,
	DamageType.CELERITY: Stat.CELERITY_WARD,
}

# ---------- Formulas ----------

## Ward formula: damage is multiplied by WARD_SCALE / (WARD_SCALE + ward).
## With 100: a ward of 100 halves damage, 300 cuts it by 75%, and it never reaches 100%.
## Raise WARD_SCALE to make wards weaker, lower it to make them stronger.
const WARD_SCALE := 100.0


static func ward_multiplier(ward: float) -> float:
	return WARD_SCALE / (WARD_SCALE + maxf(ward, 0.0))


static func ward_stat_for(damage_type: int) -> Stat:
	return WARD_FOR_TYPE[damage_type]

## Attribute values at or near this are "average". Celerity and Insight scale from it.
const ATTRIBUTE_BASELINE := 100.0
## Seconds between attacks for a unit with baseline Celerity.
const BASE_ATTACK_COOLDOWN := 1.8


## Might sets the damage of a basic attack, 1:1.
static func attack_damage(might: float) -> float:
	return might


## Celerity sets attack speed. 200 attacks twice as fast as 100; 50 is half as fast.
static func attack_cooldown(celerity: float) -> float:
	return BASE_ATTACK_COOLDOWN / maxf(celerity / ATTRIBUTE_BASELINE, 0.01)


## Insight multiplies all charge gained. 200 builds charge twice as fast.
static func charge_multiplier(insight: float) -> float:
	return maxf(insight / ATTRIBUTE_BASELINE, 0.0)

## A Gambit or passive value that scales with an attribute: a flat base plus an amount
## per point of the attribute. Every scaling effect goes through here, so changing how
## scaling works (diminishing returns, a cap) is one edit.
static func scaled(base: float, per_point: float, attribute: float) -> float:
	return base + per_point * attribute

## How much each stat grows per upgrade level, as a fraction of base (0.15 = +15% per level).
## Stats not listed don't grow.
const UPGRADE_STAT_GROWTH := {
	Stat.MIGHT: 0.15,
	Stat.INSIGHT: 0.15,
	Stat.MIGHT_WARD: .1,
	Stat.INSIGHT_WARD: .1,
	Stat.CELERITY_WARD: .1,
}
const UPGRADE_HEALTH_GROWTH := 0.2


static func upgrade_multiplier(stat: Stat, level: int) -> float:
	return 1.0 + UPGRADE_STAT_GROWTH.get(stat, 0.0) * level


static func upgrade_health_multiplier(level: int) -> float:
	return 1.0 + UPGRADE_HEALTH_GROWTH * level
