class_name PreciseShotGambit
extends Gambit
## Fires one powerful attack at Crommel's current target. It's a real attack: on top of
## normal attack damage it adds
##   Damage + Max Health Percent x the target's max health
## and anything that affects attacks affects it.

@export var damage: float = 100.0
## Extra damage as a fraction of the target's maximum health (0.35 = 35%).
@export_range(0.0, 1.0, 0.005) var max_health_percent: float = 0.35
## Added to the caster's wrack chance for this attack (0.25 = +25%).
@export var bonus_wrack_chance: float = 0.25
## The attack skips the target's wards.
@export var ignore_ward: bool = false
## After hitting, the shot bounces to the target's closest ally (ties: the lowest health)
## for this share of the damage (0.5 = half). 0 = no bounce.
@export_range(0.0, 1.0, 0.05) var ricochet_share: float = 0.0
## How far the bounce can reach, in hex cells.
@export var ricochet_range_cells: int = 3


## Only fires if there's an enemy in reach, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return _find_target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Enemies may have moved or died during the Act time, so look again now.
	var target := _find_target(caster)
	if target == null:
		return
	var shot := PreciseShot.new()
	shot.ignore_ward = ignore_ward
	shot.ricochet_share = ricochet_share
	shot.ricochet_cells = ricochet_range_cells
	caster.attack_now(target, damage + max_health_percent * target.max_health, bonus_wrack_chance, shot)


## Crommel's current target, if it's a living, targetable enemy; otherwise null.
func _find_target(caster: BattleUnit) -> BattleUnit:
	var target = caster.target
	if not is_instance_valid(target) or not target is BattleUnit:
		return null
	if not target.alive or target.team == caster.team or not target.is_targetable():
		return null
	return target
