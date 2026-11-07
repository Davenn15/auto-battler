class_name MerriboldGambit
extends Gambit
## Swings in a cone toward whichever direction hits the most enemies.
## Action damage doesn't wrack and doesn't build charge.

@export var damage: float = 150.0
## How far the swing reaches, in hex cells.
## Extra damage per point of the caster's Might. Total damage = Damage + Might Scaling × Might.
@export var might_scaling: float = 1.0
@export var range_cells: int = 2
## Total width of the cone in degrees.
@export_range(10.0, 360.0, 1.0) var cone_angle: float = 100.0
## Health the caster regains for each enemy the swing damages. 0 = none.
@export var heal_per_hit: float = 0.0

@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0


## Only casts if there's at least one enemy in reach, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_range(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Enemies may have moved or died during the Act time, so look again now.
	var enemies := _enemies_in_range(caster)
	if enemies.is_empty():
		return

	var aim := _best_direction(caster, enemies)
	_play_swing_visual(caster, aim)

	var hit_damage := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	# Gambit damage can wrack if an item lets it: one roll for the whole swing.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit_damage *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)

	var hits := 0
	for enemy in _enemies_in_cone(caster, enemies, aim):
		if not enemy.alive:
			continue
		var dealt := enemy.take_damage(hit_damage, wrack, damage_type)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
		if dealt > 0.0:
			hits += 1   # a dodged swing doesn't count
	caster.heal(heal_per_hit * hits)


func _enemies_in_range(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team:
			continue
		if caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			result.append(unit)
	return result


## Tries aiming at each enemy in turn and keeps the aim that catches the most.
## Nearer enemies are tried first, so ties go to the closest one.
func _best_direction(caster: BattleUnit, enemies: Array[BattleUnit]) -> Vector2:
	var origin := caster.global_position
	var sorted := enemies.duplicate()
	sorted.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))

	var best_dir := Vector2.RIGHT
	var best_count := -1
	for enemy in sorted:
		var dir: Vector2 = (enemy.global_position - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var count := _enemies_in_cone(caster, enemies, dir).size()
		if count > best_count:
			best_count = count
			best_dir = dir
	return best_dir


func _enemies_in_cone(caster: BattleUnit, enemies: Array[BattleUnit], dir: Vector2) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var half := deg_to_rad(cone_angle / 2.0)
	for enemy in enemies:
		var to_enemy := enemy.global_position - caster.global_position
		if to_enemy.length() < 1.0 or absf(dir.angle_to(to_enemy)) <= half:
			result.append(enemy)
	return result


## A translucent wedge that fades out, so you can see where the swing went.
func _play_swing_visual(caster: BattleUnit, dir: Vector2) -> void:
	var radius := range_cells * caster.grid.cell_spacing()
	var half := deg_to_rad(cone_angle / 2.0)
	var base := dir.angle()
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 16
	for i in steps + 1:
		var a := base - half + half * 2.0 * float(i) / steps
		points.append(Vector2(cos(a), sin(a)) * radius)

	var wedge := Polygon2D.new()
	wedge.polygon = points
	wedge.color = Color(1.0, 0.8, 0.4, 0.6)
	wedge.z_index = 10
	caster.get_tree().current_scene.add_child(wedge)
	wedge.global_position = caster.global_position

	var tween := wedge.create_tween()
	tween.tween_property(wedge, "modulate:a", 0.0, 0.25)
	tween.tween_callback(wedge.queue_free)
