class_name CurrentHealthStrikeEffect
extends Passive
## Mallet's hero Ascension: its attacks gain a Hit Effect dealing Attack Share of the
## target's current health, and each enemy its Gambit damages (the slam, or B's flying hit)
## takes Gambit Share of its current health on top.

@export var attack_share: float = 0.05
@export var gambit_share: float = 0.15


func on_battle_start(unit: BattleUnit) -> void:
	var status := CrushStatus.new()
	status.effect = self
	unit.add_status(status)


class CrushStatus extends Status:
	var effect: CurrentHealthStrikeEffect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return CrushHit.new(unit.get_credit_id(), effect.attack_share, unit.get_attack_damage_type())

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
		if amount <= 0.0 or not is_instance_valid(target) or not target.alive:
			return
		var bonus := BattleUnit.damage_bonus(unit.get_credit_id(), target, target.health * effect.gambit_share)
		var dealt := target.take_damage(bonus, 0, unit.get_attack_damage_type())
		unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)


## The attack's bonus: a share of the target's health when the attack lands.
class CrushHit extends HitEffect:
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
		var amount := BattleUnit.damage_bonus(credit_id, target, target.health * share)
		var dealt := target.take_damage(amount, wrack_level, damage_type)
		target.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
