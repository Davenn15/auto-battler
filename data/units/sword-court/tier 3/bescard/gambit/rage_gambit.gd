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
## Getting a kill while raging drops all damage the passive is holding.
@export var cleanse_on_kill: bool = false
## Getting a kill while raging resets the rage to its full duration.
@export var refresh_on_kill: bool = false
## While raging, targets are picked at random instead of nearest first.
@export var random_targets: bool = false


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var rage := RageStatus.new(duration, might_bonus, celerity_bonus, lifesteal)
	rage.cleanse_on_kill = cleanse_on_kill
	rage.refresh_on_kill = refresh_on_kill
	rage.random_targets = random_targets
	caster.add_status(rage)
