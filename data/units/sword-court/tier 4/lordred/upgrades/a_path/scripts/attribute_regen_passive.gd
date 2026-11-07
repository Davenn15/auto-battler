class_name AttributeRegenPassive
extends Passive
## Health regen scales with the unit's attributes.

## Regen per second per point of Might + Insight + Celerity (0.02 = 2 per 100 points).
@export var scaling: float = 0.02


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(AttributeRegenStatus.new(scaling))
