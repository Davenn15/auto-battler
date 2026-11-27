class_name PreciseShot
extends Projectile
## Crommel's Precise attack: a normal attack projectile with its own look, which can
## bounce once to the target's closest ally (ties: the lowest health) for a share of its
## damage.

## Share of the damage the bounce deals (0.5 = half). 0 = no bounce.
var ricochet_share: float = 0.0
## How far the bounce can travel, in hex cells.
var ricochet_cells: int = 0


func setup(p_shooter: BattleUnit, p_target: BattleUnit, p_damage: float, p_color: Color, p_wrack_level: int = 0, p_type: int = 0, p_hit_effects: Array[HitEffect] = []) -> void:
	super.setup(p_shooter, p_target, p_damage, p_color, p_wrack_level, p_type, p_hit_effects)
	polygon = PackedVector2Array([Vector2(-14, 0), Vector2(0, -5), Vector2(14, 0), Vector2(0, 5)])


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		rotation = (target.global_position - global_position).angle()   # point where it's flying
	super._physics_process(delta)


func _after_hit() -> void:
	var next := _bounce_target(target) if ricochet_share > 0.0 else null
	if next == null:
		queue_free()
		return
	# The same shot flies on to the new target, weaker, and can't bounce again.
	damage *= ricochet_share
	ricochet_share = 0.0
	target = next
	scale = Vector2.ONE * 0.7


## A reflected shot doesn't bounce.
func reflect(by: BattleUnit, wrack_chance: float, to: BattleUnit = null) -> bool:
	ricochet_share = 0.0
	return super.reflect(by, wrack_chance, to)


## The living, targetable unit on `hit`'s team closest to it (in hex cells) within
## Ricochet Cells, other than `hit`. Equally close ones: the lowest current health.
func _bounce_target(hit: BattleUnit) -> BattleUnit:
	if not is_instance_valid(hit) or hit.grid == null:
		return null
	var best: BattleUnit = null
	var best_dist := ricochet_cells + 1
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == hit or not unit.alive or unit.team != hit.team or not unit.is_targetable():
			continue
		var dist := hit.grid.get_distance(hit.cell, unit.cell)
		if dist > ricochet_cells:
			continue
		if dist < best_dist or (dist == best_dist and unit.health < best.health):
			best_dist = dist
			best = unit
	return best
