class_name InceptivePassive
extends Passive
## Extra wrack chance and wrack damage against enemies above half health.

## Added to wrack chance against healthy enemies (0.2 = +20%).
@export var bonus_chance: float = 0.2
## Added to wrack damage against healthy enemies (0.3 = wracks deal 30% more extra).
@export var bonus_damage: float = 0.3
## Share of max health an enemy must be above (0.5 = half).
@export_range(0.0, 1.0, 0.05) var threshold: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(InceptiveStatus.new(bonus_chance, bonus_damage, threshold))
