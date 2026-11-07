class_name PierceBoltGambit
extends Gambit
## Fires a large bolt in a line that pierces every enemy in its path, aimed to hit as
## many enemies as possible. Damage per enemy:
##   Damage + Might Scaling x Might + Insight Scaling x Insight + Max Health Percent x enemy max health
## Gambit damage doesn't build charge.

@export var damage: float = 100.0
@export var might_scaling: float = 0.5
@export var insight_scaling: float = 0.5
## Extra damage as a fraction of each enemy's maximum health (0.05 = 5%).
@export_range(0.0, 1.0, 0.005) var max_health_percent: float = 0.05
## How far the bolt flies, in hex cells.
@export var range_cells: int = 8
## Half-width of the bolt in pixels. Enemies whose centers pass within this are hit.
@export var bolt_radius: float = 18.0
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## Lets each enemy hit roll for wrack, using the caster's wrack chance and wrack damage.
@export var can_wrack: bool = false

## Only fires if there's at least one enemy in reach, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_reach(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Enemies may have moved or died during the Act time, so look again now.
	var enemies := _enemies_in_reach(caster)
	if enemies.is_empty():
		return

	var reach := _reach(caster)
	var dir := _best_direction(caster, enemies, reach)

	# Caster-based part is fixed at fire time; the max-health part is per enemy, at impact.
	var flat := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	flat = Stats.scaled(flat, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))

	# Wracks if A2 lets it or an item does; when it could already, items add wrack damage.
	var wrack_level := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE, can_wrack)
	var wrack_multiplier := caster.effect_wrack_multiplier(1, Stats.EffectKind.GAMBIT_DAMAGE, can_wrack)   # per level
	var bolt := PierceBolt.new()
	bolt.setup(caster.get_instance_id(), caster.team, dir, reach, bolt_radius,
			flat, max_health_percent, damage_type, wrack_level, wrack_multiplier)
	caster.get_tree().current_scene.add_child(bolt)
	bolt.global_position = caster.global_position


func _reach(caster: BattleUnit) -> float:
	var spacing := caster.grid.cell_spacing()
	return range_cells * spacing + spacing * 0.5


func _enemies_in_reach(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var reach := _reach(caster)
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team:
			continue
		if caster.global_position.distance_to(unit.global_position) <= reach:
			result.append(unit)
	return result


## Tries aiming at each enemy in turn and keeps the line that pierces the most.
## Nearer enemies are tried first, so ties go to the closest one.
func _best_direction(caster: BattleUnit, enemies: Array[BattleUnit], reach: float) -> Vector2:
	var origin := caster.global_position
	var sorted := enemies.duplicate()
	sorted.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))

	var best_dir := Vector2.RIGHT
	var best_count := -1
	for enemy in sorted:
		var dir: Vector2 = (enemy.global_position - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var count := _count_on_line(caster, enemies, dir, reach)
		if count > best_count:
			best_count = count
			best_dir = dir
	return best_dir


func _count_on_line(caster: BattleUnit, enemies: Array[BattleUnit], dir: Vector2, reach: float) -> int:
	var count := 0
	for enemy in enemies:
		var to_enemy := enemy.global_position - caster.global_position
		var along := to_enemy.dot(dir)
		if along < 0.0 or along > reach:
			continue
		if absf(to_enemy.cross(dir)) <= bolt_radius:
			count += 1
	return count
