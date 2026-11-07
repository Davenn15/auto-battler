class_name AttributeWardPassive
extends Passive
## Each ward gains a share of its matching attribute.

@export var scaling: float = 0.2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(AttributeWardStatus.new(scaling))
