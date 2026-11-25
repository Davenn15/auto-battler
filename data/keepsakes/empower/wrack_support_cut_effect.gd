class_name WrackSupportCutEffect
extends Passive
## Opportunist's Wrack Empower: an enemy the unit Wracks receives Cut less healing and
## shielding for Duration seconds.

@export var cut: float = 0.3
@export var duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Cutter.new(self))


class Cutter extends Status:
	var effect: WrackSupportCutEffect

	func _init(p_effect: WrackSupportCutEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_wrack_landed(unit: BattleUnit, target) -> void:
		if target is BattleUnit and is_instance_valid(target) and target.team != unit.team:
			SupportCutStatus.apply(target, "opportunist_%d" % unit.get_instance_id(), effect.cut, effect.duration)
