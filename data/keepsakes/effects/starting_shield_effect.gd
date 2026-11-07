class_name StartingShieldEffect
extends Passive
## Starts combat with a shield.

@export var amount: float = 400.0
## Seconds it lasts. 0 = for the rest of combat.
@export var duration: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_shield(amount, duration if duration > 0.0 else INF, unit.get_instance_id())
