class_name BloodOathEffect
extends Passive
## An Ascension effect (Sword Court, Blood Oath; a chosen unit): Grit and Vampirism, and every
## Every-th attack gains the Hit Effect: Bleed for Bleed Share of the target's max health.

@export var grit: float = 20.0
## 0.05 = 5%.
@export var vampirism: float = 0.05
@export var every: int = 3
## 0.1 = 10% of the target's max health.
@export var bleed_share: float = 0.1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BloodOathStatus.new(self))


class BloodOathStatus extends Status:
	var effect: BloodOathEffect
	var _attacks := 0

	func _init(p_effect: BloodOathEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		match stat:
			Stats.Stat.GRIT:
				return value + effect.grit
			Stats.Stat.VAMPIRISM:
				return value + effect.vampirism
		return value

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		_attacks += 1
		if _attacks < maxi(effect.every, 1):
			return null
		_attacks = 0
		return OathBleed.new(unit, effect.bleed_share)


class OathBleed extends HitEffect:
	var source_id: int
	var share: float

	func _init(p_source: BattleUnit, p_share: float) -> void:
		source_id = p_source.get_instance_id()
		share = p_share

	func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if is_instance_valid(target) and target.alive:
			Bleed.apply(target, target.max_health * share, source_id)
