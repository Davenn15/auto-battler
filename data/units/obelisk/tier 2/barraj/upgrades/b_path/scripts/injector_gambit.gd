class_name InjectorGambit
extends Gambit
## BAR.RAJ B: picks the cone in front of him that holds the most enemies, then quickly fires
## injector missiles at random angles inside it. Each missile flies straight, hits the first
## enemy it touches, deals damage and gives it Mono-Virus stacks.
## Damage = Damage + Might Scaling x Might.
##   B1: each missile pierces, hitting one more enemy.

@export var missiles: int = 5
## Width of the cone, in degrees.
@export var cone_degrees: float = 30.0
## How far the missiles fly (and how far the cone reaches), in hex cells.
@export var range_cells: int = 5
## Seconds between missiles.
@export var interval: float = 0.05
@export var damage: float = 45.0
@export var might_scaling: float = 0.35
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## Mono-Virus stacks each hit gives.
@export var virus_stacks: int = 1
## B1: extra enemies each missile can hit after the first.
@export var pierce: int = 0


func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_reach(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var enemies := _enemies_in_reach(caster)
	if enemies.is_empty():
		return
	var forward := _best_direction(caster, enemies)
	var reach := _reach(caster)
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var half := deg_to_rad(cone_degrees) / 2.0
	for i in missiles:
		var dir := forward.rotated(CombatRng.randf_range(-half, half))
		var level := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		var amount := hit * caster.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
		var missile := InjectorMissile.new()
		missile.setup(caster, dir, reach, amount, damage_type, level, virus_stacks, 1 + pierce, i * interval)
		caster.get_tree().current_scene.add_child(missile)
		missile.global_position = caster.global_position
	caster.show_float_text("Injector", InjectorMissile.COLOR)


## The cone direction that holds the most enemies. It tries aiming straight at each enemy,
## and between each pair close enough to share the cone; ties go to the nearer aim.
func _best_direction(caster: BattleUnit, enemies: Array[BattleUnit]) -> Vector2:
	var origin := caster.global_position
	var sorted := enemies.duplicate()
	sorted.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	var half := deg_to_rad(cone_degrees) / 2.0
	var angles: Array[float] = []
	for enemy in sorted:
		angles.append((enemy.global_position - origin).angle())
	var candidates: Array[float] = angles.duplicate()
	for i in angles.size():
		for j in range(i + 1, angles.size()):
			var gap := angle_difference(angles[i], angles[j])
			if absf(gap) <= half * 2.0:
				candidates.append(angles[i] + gap / 2.0)
	var best := candidates[0]
	var best_count := -1
	for aim in candidates:
		var count := 0
		for angle in angles:
			if absf(angle_difference(aim, angle)) <= half:
				count += 1
		if count > best_count:
			best_count = count
			best = aim
	return Vector2.from_angle(best)


func _reach(caster: BattleUnit) -> float:
	return (range_cells + 0.5) * caster.grid.cell_spacing()


func _enemies_in_reach(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var reach := _reach(caster)
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable() \
				and caster.global_position.distance_to(unit.global_position) <= reach:
			result.append(unit)
	return result
