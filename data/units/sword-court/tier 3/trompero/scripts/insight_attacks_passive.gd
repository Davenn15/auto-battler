class_name InsightAttacksPassive
extends Passive
## The unit's basic attacks deal Insight damage instead of their usual type, and hit
## harder the more Insight it has.

## Extra attack damage per point of Insight, added on top of the usual Might damage.
@export var insight_scaling: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(InsightAttacksStatus.new(insight_scaling))
