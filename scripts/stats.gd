class_name Stats
extends RefCounted
## One place for the attribute / damage type / ward definitions and the formulas that
## use them. Tweaking balance or renaming things should only need edits in this file.

## Every stat a unit has. Add new ones here (and in UnitData.get_base_stat).
enum Stat { MIGHT, INSIGHT, CELERITY, MIGHT_WARD, INSIGHT_WARD, CELERITY_WARD, WRACK_CHANCE, WRACK_DAMAGE, VAMPIRISM }

## The three kinds of damage. The order matches the "Might / Insight / Celerity" dropdown
## on UnitData and Gambits, so keep them in sync if you reorder or rename.
enum DamageType { MIGHT, INSIGHT, CELERITY }

## Kinds of non-attack effect that items can let wrack.
enum EffectKind { GAMBIT_DAMAGE, CONTROL, HEALING }

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
	Stat.VAMPIRISM: "Vampirism",
}

## Highest wrack level a hit can reach: 1 = wrack, 2 = Hyper-Wrack, 3 = Uber-Wrack.
const MAX_WRACK_LEVEL := 3
const HYPER_WRACK_COLOR := Color(0.561, 0.302, 0.902, 1.0)
const UBER_WRACK_COLOR := Color(0.875, 0.427, 0.984, 1.0)


## Rolls a hit's wrack level from its wrack chance: 0 = normal, 1 = wrack, 2 = Hyper-Wrack.
## Each full 100% is a guaranteed level, and what's left over is the chance of one more,
## so 1.3 always wracks and has a 30% chance to Hyper-Wrack.
static func roll_wrack(chance: float) -> int:
	var level := floori(chance)
	if CombatRng.randf() < chance - level:
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
	if wrack_level >= 3:
		return color.lerp(UBER_WRACK_COLOR, 0.7)
	if wrack_level == 2:
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


## TESTING (2026-11-11): the Insight rework. true = every unit regenerates Charge each
## second (its Charge Regen plus INSIGHT_CHARGE_REGEN per point of Insight), and Insight no
## longer multiplies other Charge. false = the old rule: no Charge Regen, and Insight
## multiplies all Charge gained. The balance sim's --old-insight flag sets it false.
static var insight_charge_regen := true
## Charge per second each point of Insight adds to Charge Regen (100 Insight = +1.5/s).
const INSIGHT_CHARGE_REGEN := 0.015


## What all Charge gained is multiplied by. Old rule: Insight / 100 (200 builds charge
## twice as fast). With the Insight rework: always 1.
static func charge_multiplier(insight: float) -> float:
	if insight_charge_regen:
		return 1.0
	return maxf(insight / ATTRIBUTE_BASELINE, 0.0)


## Charge per second a unit regenerates: its own Charge Regen plus what its Insight adds.
## 0 without the Insight rework.
static func charge_regen(base_regen: float, insight: float) -> float:
	if not insight_charge_regen:
		return 0.0
	return maxf(base_regen + INSIGHT_CHARGE_REGEN * maxf(insight, 0.0), 0.0)

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
## How many times the growth above each upgrade level gives: [level 1, level 2].
## The tier rework (Economy.tier_rework) makes level 2 count double.
const NEW_LEVEL_GROWTH_STEPS := [1.0, 2.0]
const OLD_LEVEL_GROWTH_STEPS := [1.0, 1.0]


## Growth steps a unit has at this upgrade level: 0, then 1, then 3 with the tier rework.
static func growth_steps(level: int) -> float:
	var steps: Array = NEW_LEVEL_GROWTH_STEPS if Economy.tier_rework else OLD_LEVEL_GROWTH_STEPS
	var total := 0.0
	for i in mini(level, steps.size()):
		total += steps[i]
	return total


static func upgrade_multiplier(stat: Stat, level: int) -> float:
	return 1.0 + UPGRADE_STAT_GROWTH.get(stat, 0.0) * growth_steps(level)


static func upgrade_health_multiplier(level: int) -> float:
	return 1.0 + UPGRADE_HEALTH_GROWTH * growth_steps(level)

## Extra stats and health by unit tier, so expensive units are worth their Aura.
## The old numbers were tuned with the balance sim (tools/sim_results/tier_G); the tier
## rework (Economy.tier_rework) roughly halves them. Tiers not listed get 1.
const NEW_TIER_STAT_MULTIPLIER := {2: 1.05, 3: 1.08, 4: 1.1}
const NEW_TIER_HEALTH_MULTIPLIER := {2: 1.12, 3: 1.2, 4: 1.28}
const OLD_TIER_STAT_MULTIPLIER := {2: 1.1, 3: 1.15, 4: 1.2}
const OLD_TIER_HEALTH_MULTIPLIER := {2: 1.25, 3: 1.4, 4: 1.55}
## Only these stats grow with tier. Wards and wrack stay as each unit sets them.
const TIER_SCALED_STATS := [Stat.MIGHT, Stat.INSIGHT, Stat.CELERITY]


static func tier_multiplier(stat: Stat, tier: int) -> float:
	if stat in TIER_SCALED_STATS:
		return (NEW_TIER_STAT_MULTIPLIER if Economy.tier_rework else OLD_TIER_STAT_MULTIPLIER).get(tier, 1.0)
	return 1.0


static func tier_health_multiplier(tier: int) -> float:
	return (NEW_TIER_HEALTH_MULTIPLIER if Economy.tier_rework else OLD_TIER_HEALTH_MULTIPLIER).get(tier, 1.0)


## Reserve buffs for fully upgraded units, bought in the match shop. Each buff grows the
## same stats as tiers do. PLACEHOLDER sizes until the exact rule is decided.
const BUFF_STAT_STEP := 0.05
const BUFF_HEALTH_STEP := 0.15


static func buff_multiplier(stat: Stat, buffs: int) -> float:
	return 1.0 + BUFF_STAT_STEP * buffs if stat in TIER_SCALED_STATS else 1.0


static func buff_health_multiplier(buffs: int) -> float:
	return 1.0 + BUFF_HEALTH_STEP * buffs
