class_name DodgeStrikeEffect
extends Passive
## Frame's hero Ascension (with +10% dodge chance from the Ascension's own stats): whenever
## it dodges, its next attack gains a Hit Effect dealing Share of the target's max health as
## bonus damage. On B, the attacks Frame makes alongside the ally it follows count too.

## 0.05 = 5% of the target's max health.
@export var share: float = 0.05

const COLOR := Color(0.55, 0.9, 1.0)


func on_battle_start(unit: BattleUnit) -> void:
	var status := ReadyStatus.new()
	status.share = share
	unit.add_status(status)


class ReadyStatus extends Status:
	var share: float
	var _primed := false

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_dodge(unit: BattleUnit) -> void:
		if not _primed:
			_primed = true
			KeepsakeVfx.set_glow(unit, "VfxCounterstep", DodgeStrikeEffect.COLOR, 0.35)

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		if not _primed:
			return null
		_primed = false
		KeepsakeVfx.clear(unit, "VfxCounterstep")
		return CounterHit.new(unit.get_credit_id(), share, unit.get_attack_damage_type())


## The bonus hit, fixed when the attack is made.
class CounterHit extends HitEffect:
	var credit_id: int
	var share: float
	var damage_type: int

	func _init(p_credit_id: int, p_share: float, p_type: int) -> void:
		credit_id = p_credit_id
		share = p_share
		damage_type = p_type

	func apply(target: BattleUnit, _dealt: float, wrack_level: int) -> void:
		if not target.alive:
			return
		var amount := BattleUnit.damage_bonus(credit_id, target, target.max_health * share)
		var dealt := target.take_damage(amount, wrack_level, damage_type)
		target.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
