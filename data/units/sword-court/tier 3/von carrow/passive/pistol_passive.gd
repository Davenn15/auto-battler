class_name PistolPassive
extends Passive
## Every few attacks, the unit fires a longer-range pistol shot with extra wrack chance.

## 3 = every third attack is a pistol shot.
@export var every: int = 3
## The shot's attack range, in hex cells.
@export var pistol_range: int = 4
## Added to wrack chance for the shot (0.25 = +25%).
@export var wrack_bonus: float = 0.25
## Most shots she can have loaded at once.
@export var max_shots: int = 6
## Extra damage per point of Might on pistol shots, on top of the normal 1 per point.
## 0.5 = shots deal 1.5x Might.
@export var extra_might_scaling: float = 0.5

func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(PistolStatus.new(every, pistol_range, wrack_bonus, max_shots, extra_might_scaling))
