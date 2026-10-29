class_name WrackDamagePassive
extends Passive
## Increases the unit's wrack damage for the whole battle.

## Added to wrack damage. Wrack damage is the extra damage of a wrack as a fraction of
## normal damage, so with the default 0.3 base, +0.25 makes wracks deal 55% extra.
@export var bonus_wrack_damage: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(WrackDamageStatus.new(bonus_wrack_damage))
