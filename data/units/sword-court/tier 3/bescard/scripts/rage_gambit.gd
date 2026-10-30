class_name RageGambit
extends Gambit
## Flies into a rage for a few seconds: bonus Might and Celerity, and attacks heal the
## caster for a share of the damage they deal.

## Seconds the rage lasts.
@export var duration: float = 5.0
@export var might_bonus: float = 40.0
## At baseline 100, +50 is 50% faster attacks.
@export var celerity_bonus: float = 50.0
## Fraction of attack damage dealt that heals the caster (0.3 = 30%).
@export_range(0.0, 1.0, 0.01) var lifesteal: float = 0.3


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	caster.add_status(RageStatus.new(duration, might_bonus, celerity_bonus, lifesteal))
