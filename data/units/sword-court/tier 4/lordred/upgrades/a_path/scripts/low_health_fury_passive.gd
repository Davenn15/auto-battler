class_name LowHealthFuryPassive
extends Passive
## Lordred A (Ruinous): gains Might, Insight and Celerity the lower his health is.
## Lordred B (Vainglorious), with Boost Wards: gains Wards instead.

## The bonus to each stat as health nears zero. At half health he has half of it.
@export var max_bonus: float = 75.0
## True: the bonus goes to his three Wards instead of his three attributes.
@export var boost_wards: bool = false


func on_battle_start(unit: BattleUnit) -> void:
	var stats := LowHealthFuryStatus.WARDS if boost_wards else LowHealthFuryStatus.ATTRIBUTES
	unit.add_status(LowHealthFuryStatus.new(max_bonus, stats))
