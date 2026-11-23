class_name RangeTradeShieldEffect
extends Passive
## An Ascension effect (Point Blank): the unit loses Range Loss attack range (never below
## 1), and gains a Shield of Shield Share of its max health for Shield Duration seconds
## each time it plays its Gambit. (Its stat gains are the Ascension's own stats.)

@export var range_loss: int = 2
@export_range(0.0, 1.0, 0.01) var shield_share: float = 0.3
@export var shield_duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.attack_range = maxi(unit.attack_range - range_loss, 1)
	unit.add_status(GambitShieldStatus.new(self))


class GambitShieldStatus extends Status:
	var effect: RangeTradeShieldEffect

	func _init(p_effect: RangeTradeShieldEffect) -> void:
		effect = p_effect

	func on_gambit_played(unit: BattleUnit) -> void:
		unit.add_shield(unit.max_health * effect.shield_share, effect.shield_duration, unit.get_instance_id())
