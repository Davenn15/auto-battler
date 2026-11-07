class_name SpitePassive
extends Passive
## Whenever an enemy attacks the unit, it flings a blade shard back.

## Shard damage = Damage + Might Scaling x Might.
@export var damage: float = 30.0
@export var might_scaling: float = 0.2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SpiteStatus.new(damage, might_scaling))
