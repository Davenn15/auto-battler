class_name WardAttackPassive
extends Passive
## Balmede B1: her attacks deal extra damage equal to Ward Share of her three Wards added
## together, read live (so her passive and Plant count).

## 0.4 = +40% of her total Wards.
@export var ward_share: float = 0.4


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(WardAttackStatus.new(ward_share))


class WardAttackStatus extends Status:
	var share: float

	func _init(p_share: float) -> void:
		share = p_share

	func modify_outgoing_damage(unit: BattleUnit, damage: float) -> float:
		var wards := unit.get_stat(Stats.Stat.MIGHT_WARD) + unit.get_stat(Stats.Stat.INSIGHT_WARD) \
				+ unit.get_stat(Stats.Stat.CELERITY_WARD)
		return damage + wards * share
