class_name ShardBoostEffect
extends Passive
## A Shard Ascension's effect: every Shard of Shard Kind the unit holds, loose or as part
## of a Keepsake (both halves count, and so does the Shard an Empowered Keepsake was
## empowered with), gives the bonus below once. Counted live, so Shards gained mid-combat
## (Vestibule's Gift, Column's Fabricator) count too.

@export var shard_kind: Shard.Kind = Shard.Kind.MIGHT

@export_group("Bonus per Shard")
@export var might: float = 0.0
@export var insight: float = 0.0
@export var celerity: float = 0.0
## 0.05 = +5% Wrack Chance.
@export var wrack_chance: float = 0.0
## 0.03 = +3% Vampirism.
@export var vampirism: float = 0.0
## Points (5 = 5% Scar).
@export var scar: float = 0.0
## Points (5 = 5 Grit).
@export var grit: float = 0.0
## Points (5 = 5 Immovability).
@export var immovability: float = 0.0
## 0.03 = +3% dodge chance.
@export var dodge_chance: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShardBoostStatus.new(self))


## How many Shards of `kind` the unit holds, counting each half of a Keepsake and the Shard
## an Empowered Keepsake was empowered with.
static func count(unit: BattleUnit, kind: int) -> int:
	var total := 0
	for keepsake in unit.keepsakes:
		if keepsake == null:
			continue
		if keepsake.is_shard:
			total += 1 if keepsake.first_shard == kind else 0
			continue
		total += (1 if keepsake.first_shard == kind else 0) + (1 if keepsake.second_shard == kind else 0)
		if keepsake.is_empowered() and keepsake.empowered_with == kind:
			total += 1
	return total


func bonuses() -> Dictionary:
	return {
		Stats.Stat.MIGHT: might, Stats.Stat.INSIGHT: insight, Stats.Stat.CELERITY: celerity,
		Stats.Stat.WRACK_CHANCE: wrack_chance, Stats.Stat.VAMPIRISM: vampirism,
		Stats.Stat.SCAR: scar, Stats.Stat.GRIT: grit, Stats.Stat.IMMOVABILITY: immovability,
	}


class ShardBoostStatus extends Status:
	var effect: ShardBoostEffect
	var _bonuses: Dictionary

	func _init(p_effect: ShardBoostEffect) -> void:
		effect = p_effect
		_bonuses = p_effect.bonuses()

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		var per: float = _bonuses.get(stat, 0.0)
		if per == 0.0:
			return value
		return value + per * ShardBoostEffect.count(unit, effect.shard_kind)

	func modify_dodge_chance(unit: BattleUnit, chance: float) -> float:
		if effect.dodge_chance <= 0.0:
			return chance
		return chance + effect.dodge_chance * ShardBoostEffect.count(unit, effect.shard_kind)
