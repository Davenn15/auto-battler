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

## Highest wrack level a hit can reach: 1 = wrack, 2 = Hyper-Wrack.
const MAX_WRACK_LEVEL := 2
const HYPER_WRACK_COLOR := Color(1.0, 0.3, 0.9)


## Rolls a hit's wrack level from its wrack chance: 0 = normal, 1 = wrack, 2 = Hyper-Wrack.
## Each full 100% is a guaranteed level, and what's left over is the chance of one more,
## so 1.3 always wracks and has a 30% chance to Hyper-Wrack.
static func roll_wrack(chance: float) -> int:
	var level := floori(chance)
	if randf() < chance - level:
		level += 1
	return mini(level, MAX_WRACK_LEVEL)


## Damage multiplier for a wrack level: the wrack multiplier once per level.
static func wrack_multiplier(level: int, wrack_damage: float) -> float:
	return pow(1.0 + wrack_damage, level)

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


## The color to show damage of this type in: brighter for a wrack, tinted toward the
## Hyper-Wrack color for a Hyper-Wrack.
static func damage_color(damage_type: int, wrack_level: int = 0) -> Color:
	var color: Color = DAMAGE_TYPE_COLORS.get(damage_type, Color.WHITE)
	if wrack_level >= 2:
		return color.lerp(HYPER_WRACK_COLOR, 0.6)
	return color.lightened(WRACK_BRIGHTEN) if wrack_level == 1 else color

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

## Extra stats and health by unit tier, so expensive units are worth their Aura.
## Tuned with the balance sim (tools/sim_results/tier_G). Tiers not listed get 1.
const TIER_STAT_MULTIPLIER := {2: 1.1, 3: 1.15, 4: 1.2}
const TIER_HEALTH_MULTIPLIER := {2: 1.25, 3: 1.4, 4: 1.55}
## Only these stats grow with tier. Wards and wrack stay as each unit sets them.
const TIER_SCALED_STATS := [Stat.MIGHT, Stat.INSIGHT, Stat.CELERITY]


static func tier_multiplier(stat: Stat, tier: int) -> float:
	if stat in TIER_SCALED_STATS:
		return TIER_STAT_MULTIPLIER.get(tier, 1.0)
	return 1.0


static func tier_health_multiplier(tier: int) -> float:
	return TIER_HEALTH_MULTIPLIER.get(tier, 1.0)
