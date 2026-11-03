class_name PreciseShotGambit
extends Gambit
## Fires one powerful attack at the enemy in reach with the most health. It's a real
## attack: on top of normal attack damage it adds
##   Damage + Max Health Percent x the target's max health
## and anything that affects attacks affects it.

@export var damage: float = 100.0
## Extra damage as a fraction of the target's maximum health (0.35 = 35%).
@export_range(0.0, 1.0, 0.005) var max_health_percent: float = 0.35
## Added to the caster's wrack chance for this attack (0.25 = +25%).
@export var bonus_wrack_chance: float = 0.25
## How far it can pick a target, in hex cells.
@export var range_cells: int = 8
## The attack skips the target's wards.
@export var ignore_ward: bool = false
## After hitting, the shot bounces to the nearest other enemy for this share of the
## damage (0.5 = half). 0 = no bounce.
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
	var spacing := caster.grid.cell_spacing()
	var shot := PreciseShot.new()
	shot.ignore_ward = ignore_ward
	shot.ricochet_share = ricochet_share
	shot.ricochet_reach = ricochet_range_cells * spacing + spacing * 0.5
	caster.attack_now(target, damage + max_health_percent * target.max_health, bonus_wrack_chance, shot)


## The targetable enemy in reach with the most total health, or null if there's none.
func _find_target(caster: BattleUnit) -> BattleUnit:
	var spacing := caster.grid.cell_spacing()
	var reach := range_cells * spacing + spacing * 0.5
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable():
			continue
		if caster.global_position.distance_to(unit.global_position) > reach:
			continue
		if best == null or unit.max_health > best.max_health:
			best = unit
	return best
