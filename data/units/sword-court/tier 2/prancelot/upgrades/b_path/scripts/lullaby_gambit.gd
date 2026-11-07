class_name LullabyGambit
extends Gambit
## Strums a lulling wave forward along the line that catches the most enemies. Every
## enemy in it falls asleep for a while, waking early if it takes enough damage.

const WAVE_COLOR := Color(0.786, 0.318, 0.572, 1.0)   # soft moonlight

## How far the wave reaches, in hex cells.
@export var length_cells: int = 3
## How wide it is, in hex cells.
@export var width_cells: float = 1.5
## Seconds enemies sleep.
@export var sleep_time: float = 3.0
## Damage that wakes a sleeper, as a share of its max health (0.15 = 15%).
@export_range(0.0, 1.0, 0.05) var wake_share: float = 0.15
## Share of sleepers' wards removed while asleep (0.4 = 40% lower). 0 = none.
@export_range(0.0, 1.0, 0.05) var ward_cut: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return _best_aim(caster)["count"] > 0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var aim := _best_aim(caster)
	if aim["count"] == 0:
		return
	var dir: Vector2 = aim["dir"]
	_play_wave(caster, dir)
	# An item can let control effects wrack: one roll lengthens every sleep and its ward cut.
	var control := caster.wrack_effect_multiplier(Stats.EffectKind.CONTROL)
	for enemy in _enemies(caster):
		if not SlamGambit.in_rectangle(enemy.global_position, caster.global_position, dir, _length(caster), _half_width(caster)):
			continue
		if enemy.is_cc_immune():
			enemy.show_float_text("Immune", Color(0.8, 0.8, 0.8))
			continue
		for old in enemy.statuses.duplicate():
			if old is SleepStatus:
				enemy.remove_status(old)   # a new lullaby restarts the sleep
		enemy.add_status(SleepStatus.new(sleep_time * control, enemy.max_health * wake_share,
				minf(ward_cut * control, 0.95)))


## The direction, toward some enemy, whose wave catches the most enemies.
func _best_aim(caster: BattleUnit) -> Dictionary:
	var origin := caster.global_position
	var enemies := _enemies(caster).filter(
			func(e): return origin.distance_to(e.global_position) <= _length(caster))
	var best := {"dir": Vector2.RIGHT, "count": 0}
	for enemy in enemies:
		var dir: Vector2 = (enemy.global_position - origin).normalized()
		if dir == Vector2.ZERO:
			continue
		var count := enemies.filter(func(e): return SlamGambit.in_rectangle(
				e.global_position, origin, dir, _length(caster), _half_width(caster))).size()
		if count > best["count"]:
			best = {"dir": dir, "count": count}
	return best


func _enemies(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team:
			result.append(unit)
	return result


func _length(caster: BattleUnit) -> float:
	var spacing := caster.grid.cell_spacing()
	return length_cells * spacing + spacing * 0.5


func _half_width(caster: BattleUnit) -> float:
	return width_cells * caster.grid.cell_spacing() * 0.5


## A soft rectangle along the wave that fades out.
func _play_wave(caster: BattleUnit, dir: Vector2) -> void:
	var length := _length(caster)
	var half := _half_width(caster)
	var rect := Polygon2D.new()
	rect.polygon = PackedVector2Array([Vector2(0, -half), Vector2(length, -half),
			Vector2(length, half), Vector2(0, half)])
	rect.color = Color(WAVE_COLOR, 0.45)
	rect.rotation = dir.angle()
	rect.z_index = 10
	caster.get_tree().current_scene.add_child(rect)
	rect.global_position = caster.global_position
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.5)
	tween.tween_callback(rect.queue_free)
