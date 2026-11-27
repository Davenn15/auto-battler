class_name SlamGambit
extends Gambit
## Geomond's base Gambit. He leaps to the ally within Leap Cells with the lowest share of
## its health and gives them both a Shield of (Shield Share + Shield Per Insight x Insight)
## of each one's own max health, and Ward Amount + Ward Might Scaling x Might to all three
## Wards, for Support Duration seconds. With no ally in reach he stays put and only shields
## himself. Then he flips into the air and slams the wide line that hits the most enemies:
##   Damage + Might Scaling x Might + Max Health Percent x the enemy's max health
## and stuns each enemy hit for Stun Time.
##   A (Tectonic): the slam deals Fewer Targets Bonus more for each enemy it hits fewer than
##      Fewer Targets Count.
##   A1: up to Low Health Bonus more on hurt enemies (grows with their missing health).

const SLAM_COLOR := Color(1.0, 0.45, 0.1)   # magma orange

@export_group("Leap and support")
## How far away an ally can be for him to leap to it, in hex cells.
@export var leap_cells: int = 3
## Seconds the leap takes, and how high he goes (pixels).
@export var leap_time: float = 0.45
@export var leap_height: float = 40.0
## Shield: this share of the receiver's max health (0.12 = 12%)...
@export var shield_share: float = 0.12
## ...plus this much more per point of Geomond's Insight (0.0006 = 6% per 100 Insight).
@export var shield_per_insight: float = 0.0006
## Added to all three Wards: Ward Amount + Ward Might Scaling x Geomond's Might.
@export var ward_amount: float = 20.0
@export var ward_might_scaling: float = 0.15
## Seconds the Shield and Wards last.
@export var support_duration: float = 5.0

@export_group("Slam")
@export var damage: float = 120.0
@export var might_scaling: float = 0.8
## Extra slam damage as a share of each enemy's max health (0.06 = 6%).
@export_range(0.0, 1.0, 0.005) var max_health_percent: float = 0.06
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## How far the slam reaches from him, and how wide it is, in hex cells.
@export var length_cells: int = 4
@export var width_cells: float = 2.0
@export var stun_time: float = 1.0
## Seconds of the flip before the slam lands.
@export var spin_time: float = 0.35

@export_group("Upgrades")
## A: extra damage for each enemy the slam hits fewer than Fewer Targets Count (0.3 = +30%).
@export var fewer_targets_bonus: float = 0.0
@export var fewer_targets_count: int = 4
## A1: the most extra damage on a hurt enemy (0.75 = up to +75%), scaling with its missing
## health: none at full health, all of it at none.
@export var low_health_bonus: float = 0.0


## Casts whenever there's an enemy to slam at all; the support half never goes to waste.
func can_use(caster: BattleUnit) -> bool:
	return not _living_enemies(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	caster.lock_for(leap_time + spin_time + 0.1)
	var ally := _leap_target(caster)
	if ally != null:
		await MalletFx.leap(caster, _landing_cell(caster, ally), leap_time, leap_height)
		if not _alive(caster):
			return
	_support(caster, caster)
	if ally != null and _alive(ally):
		_support(caster, ally)
	caster.show_float_text("Slam", SLAM_COLOR)
	await GeomondFx.spin(caster, spin_time)
	if _alive(caster) and caster.active:
		_slam(caster)


## The ally (never himself) within Leap Cells with the lowest share of its health, or null.
func _leap_target(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive or unit.team != caster.team \
				or caster.grid.get_distance(caster.cell, unit.cell) > leap_cells:
			continue
		if best == null or unit.health / unit.max_health < best.health / best.max_health:
			best = unit
	return best


## Where to land: where he stands if he's already next to `ally`, else the free cell next to
## it nearest to him (or where he stands, if there's none).
func _landing_cell(caster: BattleUnit, ally: BattleUnit) -> Vector2i:
	var grid := caster.grid
	if grid.get_distance(caster.cell, ally.cell) <= 1:
		return caster.cell
	var cells := grid.free_cells_in_range(ally.cell, 1)
	if cells.is_empty():
		return caster.cell
	cells.sort_custom(func(a, b): return grid.get_distance(caster.cell, a) < grid.get_distance(caster.cell, b))
	return cells[0]


## The Shield and Wards he gives `unit` (himself or the ally).
func _support(caster: BattleUnit, unit: BattleUnit) -> void:
	var share := shield_share + shield_per_insight * caster.get_stat(Stats.Stat.INSIGHT)
	unit.add_shield(unit.max_health * share, support_duration, caster.get_instance_id(), false, true)
	var wards := Stats.scaled(ward_amount, ward_might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	for ward in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
		unit.add_status(TimedStatStatus.new(ward, wards, support_duration))
	BattleUnit.gambit_affected(caster, unit)
	GeomondFx.rings(unit)


func _slam(caster: BattleUnit) -> void:
	var origin := caster.global_position
	var enemies := _living_enemies(caster)
	var aim := _best_aim(caster, origin, enemies)
	GeomondFx.slam_line(caster, origin, aim["dir"], _length(caster), _half_width(caster))
	var hit: Array[BattleUnit] = []
	for enemy in enemies:
		if enemy.alive and _is_in_slam(caster, origin, enemy, aim["dir"]):
			hit.append(enemy)
	if hit.is_empty():
		return   # everyone got out of the way
	var flat := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var fewer := 1.0 + fewer_targets_bonus * maxi(fewer_targets_count - hit.size(), 0)
	# Gambit damage can Wrack if an item lets it: one roll for the whole slam.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	var wrack_multiplier := caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	for enemy in hit:
		var missing := 1.0 - clampf(enemy.health / enemy.max_health, 0.0, 1.0)
		var amount := (flat + max_health_percent * enemy.max_health) * fewer \
				* (1.0 + low_health_bonus * missing) * wrack_multiplier
		var dealt := enemy.take_damage(BattleUnit.damage_bonus(caster, enemy, amount), wrack, damage_type)
		BattleUnit.gambit_damage_dealt(caster, enemy, dealt)   # Gambit damage (see BattleUnit)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
		if dealt > 0.0 and enemy.alive and stun_time > 0.0:
			enemy.stun(stun_time, caster)


## The best way to aim the slam from `origin`: tries aiming at each enemy in reach and keeps
## the aim that hits the most. Nearer enemies are tried first, so ties go to the closest.
## Returns {"dir": Vector2, "count": enemies it hits}.
func _best_aim(caster: BattleUnit, origin: Vector2, enemies: Array[BattleUnit]) -> Dictionary:
	var reach := _length(caster)
	var in_reach := enemies.filter(func(e): return origin.distance_to(e.global_position) <= reach + _half_width(caster))
	in_reach.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	var best := {"dir": Vector2.RIGHT, "count": 0}
	if caster.target != null and is_instance_valid(caster.target):
		best["dir"] = (caster.target.global_position - origin).normalized()
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


func _is_in_slam(caster: BattleUnit, origin: Vector2, enemy: BattleUnit, dir: Vector2) -> bool:
	return in_rectangle(enemy.global_position, origin, dir, _length(caster), _half_width(caster))


## Pixels from him to the far end of the slam.
func _length(caster: BattleUnit) -> float:
	var spacing := caster.grid.cell_spacing()
	return length_cells * spacing + spacing * 0.5


## Pixels from the slam's centre line to either side.
func _half_width(caster: BattleUnit) -> float:
	return width_cells * caster.grid.cell_spacing() * 0.5


func _living_enemies(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team:
			result.append(unit)
	return result


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
