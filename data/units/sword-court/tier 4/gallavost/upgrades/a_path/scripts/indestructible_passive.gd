class_name IndestructiblePassive
extends Passive
## After gaining a shield, the unit briefly gains a lot of dodge chance.

## Extra dodge chance (0.5 = +50%).
@export_range(0.0, 1.0, 0.05) var bonus_dodge: float = 0.5
## Seconds the extra dodge lasts after each shield.
@export var duration: float = 2.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(IndestructibleStatus.new(bonus_dodge, duration))


func IndestructiblePassive_Status_placeholder() -> IndestructibleStatus:
	return IndestructibleStatus.new(bonus_dodge, duration)
