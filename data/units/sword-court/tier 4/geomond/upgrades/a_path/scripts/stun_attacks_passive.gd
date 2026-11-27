class_name GeomondStunPassive
extends Passive
## Geomond A2: his attacks stun what they hit for Duration seconds (StunAttacksStatus, as
## Sumpton's attacks do).

@export var duration: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StunAttacksStatus.new(duration))
