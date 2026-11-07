class_name SlamGambit
extends Gambit
## Dashes to the spot where the slam hits the most enemies, gains a shield, then channels
## a huge slam: a long rectangle in front of the caster. Damage per enemy:
##   Damage + Might Scaling x Might + Max Health Percent x that enemy's max health

const SLAM_COLOR := Color(1.0, 0.45, 0.1)   # magma orange

@export var damage: float = 150.0
@export var might_scaling: float = 1.0
## Extra slam damage as a fraction of each enemy's max health (0.12 = 12%).
@export_range(0.0, 1.0, 0.005) var max_health_percent: float = 0.12
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## How far the slam reaches from the caster, in hex cells.
@export var length_cells: int = 3
## How wide the slam is, in hex cells. 1 = a single line of hexes.
@export var width_cells: float = 1.0
## How far the dash can go, in hex cells. 0 = no dash.
@export var dash_cells: int = 2
## Seconds the dash takes.
@export var dash_time: float = 0.15
## Shield gained when the dash ends.
@export var shield_amount: float = 250.0
@export var shield_duration: float = 3.0
## Seconds spent winding up the slam. The unit can't move or attack meanwhile.
@export var channel_time: float = 1.0
## Added to all three wards while winding up the slam. 0 = none.
@export var channel_ward_bonus: float = 0.0
## Seconds the slam leaves a lava pool behind. 0 = no pool.
@export var lava_duration: float = 0.0
## Lava damage per second to each enemy inside = Lava Damage + Lava Might Scaling x Might.
@export var lava_damage: float = 40.0
@export var lava_insight_scaling: float = 0.2


## Only fires if some spot in dash range lets the slam hit an enemy, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return _best_spot(caster)["count"] > 0


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	# Enemies may have moved during the Act time, so look again now.
	var spot := _best_spot(caster)
	if spot["count"] == 0:
		return
	caster.lock_for(dash_time + channel_time)
	await caster.dash_to( spot["cell"], dash_time)
	if not _alive(caster):
		return
	caster.add_shield(shield_amount, shield_duration, caster.get_instance_id())
	if channel_ward_bonus > 0.0:
		caster.add_status(ChannelWardStatus.new(channel_ward_bonus, channel_time))
	caster.show_float_text("Slam", SLAM_COLOR)
	await caster.get_tree().create_timer(channel_time, true, true).timeout
	# The caster may have died, or the battle ended, while winding up.
	if _alive(caster) and caster.active:
		_slam(caster)



func _slam(caster: BattleUnit) -> void:
	# Aimed again now: enemies may have moved during the wind-up.
	var origin := caster.global_position
	var enemies := _living_enemies(caster)
	var aim := _best_aim(caster, origin, enemies)
	if aim["count"] == 0:
		return   # everyone got out of the way
	_play_slam_visual(caster, aim["dir"])
	var flat := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	# Gambit damage can wrack if an item lets it: one roll for the whole slam.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	var wrack_multiplier := caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	for enemy in enemies:
		if not enemy.alive or not _is_in_slam(caster, origin, enemy, aim["dir"]):
			continue
		var amount := (flat + max_health_percent * enemy.max_health) * wrack_multiplier
		var dealt := enemy.take_damage(amount, wrack, damage_type)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
	if lava_duration > 0.0:
		var pool := LavaPool.new()
		pool.setup(caster, origin, aim["dir"], _length(caster), _half_width(caster),
				Stats.scaled(lava_damage, lava_insight_scaling, caster.get_stat(Stats.Stat.INSIGHT)),
				lava_duration, damage_type)
		caster.get_tree().current_scene.add_child(pool)
		pool.global_position = origin


## Where to slam from: the caster's own cell, or a free cell within dash range, whichever
## lets the slam hit the most enemies. Ties go to staying put, then to the nearest cell.
## Returns {"cell": Vector2i, "count": enemies the slam would hit from there}.
func _best_spot(caster: BattleUnit) -> Dictionary:
	var grid := caster.grid
	var enemies := _living_enemies(caster)
	var best := {"cell": caster.cell, "count": _best_aim(caster, caster.global_position, enemies)["count"]}
	if dash_cells <= 0:
		return best
	var cells := grid.free_cells_in_range(caster.cell, dash_cells)
	cells.sort_custom(func(a, b): return grid.get_distance(caster.cell, a) < grid.get_distance(caster.cell, b))
	for cell in cells:
		var count: int = _best_aim(caster, grid.cell_to_world(cell), enemies)["count"]
		if count > best["count"]:
			best = {"cell": cell, "count": count}
	return best


## The best way to aim a slam from `origin`: tries aiming at each enemy in reach and keeps
## the aim that hits the most. Nearer enemies are tried first, so ties go to the closest.
## Returns {"dir": Vector2, "count": enemies it hits}.
func _best_aim(caster: BattleUnit, origin: Vector2, enemies: Array[BattleUnit]) -> Dictionary:
	var reach := _length(caster)
	var in_reach := enemies.filter(func(e): return origin.distance_to(e.global_position) <= reach)
	in_reach.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	var best := {"dir": Vector2.RIGHT, "count": 0}
	for enemy in in_reach:
		var dir: Vector2 = (enemy.global_position - origin).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		var count := in_reach.filter(func(e): return _is_in_slam(caster, origin, e, dir)).size()
		if count > best["count"]:
			best = {"dir": dir, "count": count}
	return best


## True if `point` lies in a rectangle that starts at `origin`, runs `length` pixels along
## `dir`, and reaches `half_width` pixels to each side.
static func in_rectangle(point: Vector2, origin: Vector2, dir: Vector2, length: float, half_width: float) -> bool:
	var to_point := point - origin
	var along := to_point.dot(dir)           # how far forward
	var across := absf(to_point.cross(dir))  # how far to the side
	return along >= 0.0 and along <= length and across <= half_width


## True if `enemy` stands inside a slam from `origin` aimed along `dir`.
func _is_in_slam(caster: BattleUnit, origin: Vector2, enemy: BattleUnit, dir: Vector2) -> bool:
	return in_rectangle(enemy.global_position, origin, dir, _length(caster), _half_width(caster))


## Pixels from the caster to the far end of the slam.
func _length(caster: BattleUnit) -> float:
	var spacing := caster.grid.cell_spacing()
	return length_cells * spacing + spacing * 0.5


## Pixels from the slam's center line to either side.
func _half_width(caster: BattleUnit) -> float:
	return width_cells * caster.grid.cell_spacing() * 0.5


func _living_enemies(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team:
			result.append(unit)
	return result


## A translucent rectangle along the slam that fades out.
func _play_slam_visual(caster: BattleUnit, dir: Vector2) -> void:
	var length := _length(caster)
	var half := _half_width(caster)
	var rect := Polygon2D.new()
	rect.polygon = PackedVector2Array([Vector2(0, -half), Vector2(length, -half),
			Vector2(length, half), Vector2(0, half)])
	rect.color = Color(SLAM_COLOR, 0.6)
	rect.rotation = dir.angle()
	rect.z_index = 10
	caster.get_tree().current_scene.add_child(rect)
	rect.global_position = caster.global_position
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(rect.queue_free)

## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
