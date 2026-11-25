class_name SaviourWrackEffect
extends Passive
## Saviour's Wrack Empower: when a heal the unit gives Wracks, the target also gains a
## Shield of Shield Share of it; when a shield it gives Wracks, the target gains Celerity.

@export var shield_share: float = 0.5
@export var shield_duration: float = 4.0
@export var celerity: float = 20.0
@export var celerity_duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Grace.new(self))


class Grace extends Status:
	var effect: SaviourWrackEffect
	var _giving := false   # the follow-up shield doesn't set off another follow-up

	func _init(p_effect: SaviourWrackEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_support_wracked(unit: BattleUnit, target: BattleUnit, amount: float, is_shield: bool) -> void:
		if _giving or not is_instance_valid(target) or not target.alive:
			return
		_giving = true
		if is_shield:
			target.add_status(TimedStatStatus.new(Stats.Stat.CELERITY, effect.celerity, effect.celerity_duration))
		else:
			target.add_shield(amount * effect.shield_share, effect.shield_duration, unit.get_instance_id())
		_giving = false
