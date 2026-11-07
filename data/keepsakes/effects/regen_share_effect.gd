class_name RegenShareEffect
extends Passive
## Extra health regen equal to a share of max health per second.

## 0.04 = regenerate 4% of max health every second.
@export var share: float = 0.04


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Mending.new(share))


class Mending extends Status:
	var share: float

	func _init(p_share: float) -> void:
		share = p_share

	func modify_health_regen(unit: BattleUnit, regen: float) -> float:
		return regen + unit.max_health * share
