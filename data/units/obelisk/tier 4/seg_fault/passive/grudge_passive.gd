class_name SegGrudgePassive
extends Passive
## SEG.FAULT: each of its attacks deals bonus Pure Damage: Share of the damage its target
## has dealt this combat (at most Cap per attack; 0 = no cap). Worked out when the attack
## lands.

@export_range(0.0, 1.0, 0.005) var share: float = 0.02
@export var cap: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GrudgeStatus.new(self))


class GrudgeStatus extends Status:
	var passive: SegGrudgePassive

	func _init(p_passive: SegGrudgePassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return GrudgeHit.new(unit.get_credit_id(), passive.share, passive.cap)


class GrudgeHit extends HitEffect:
	var credit_id: int
	var share: float
	var cap: float

	func _init(p_credit: int, p_share: float, p_cap: float) -> void:
		credit_id = p_credit
		share = p_share
		cap = p_cap

	func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if not is_instance_valid(target) or not target.alive:
			return
		var bonus := target.damage_dealt * share
		if cap > 0.0:
			bonus = minf(bonus, cap)
		if bonus <= 0.0:
			return
		var dealt := target.take_damage(BattleUnit.damage_bonus(credit_id, target, bonus), 0, Stats.DamageType.PURE)
		target.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
