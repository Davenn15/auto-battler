class_name BladehookGambit
extends Gambit
## Codger throws his bladehook at the farthest enemy in reach: it takes Damage + Might
## Scaling x Might, is dragged up to Pull Cells closer to him, then is stunned.
##   A: more reach and pull.  A1: enemies the hook passes are stunned too.
##   A2: more reach again.

@export var damage: float = 140.0
@export var might_scaling: float = 1.0
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## How far the hook reaches, in hex cells.
@export var range_cells: int = 4
## How many cells the target is dragged toward him.
@export var pull_cells: int = 2
## Seconds the target is stunned once it lands.
@export var stun_duration: float = 1.25
## A1: 1 = enemies the hook passes on its way are stunned too (for Stun Duration).
@export var stun_path: float = 0.0

const FLIGHT_TIME := 0.18
const PULL_TIME := 0.2


func can_use(caster: BattleUnit) -> bool:
	return _pick_target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var target := _pick_target(caster)
	if target == null:
		refund(caster)   # its target died or left reach during the wind-up
		return
	var start := caster.global_position
	var hook := CodgerFx.throw_hook(caster, target.global_position, FLIGHT_TIME)
	await caster.get_tree().create_timer(FLIGHT_TIME, true, true).timeout
	if not _alive(caster) or not _alive(target):
		CodgerFx.reel_in(hook, null, 0.05)
		return
	# A1: everyone the hook passed on the way is stunned too.
	if stun_path > 0.0:
		for enemy in _enemies_on_path(caster, start, target):
			enemy.stun(stun_duration, caster)
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var dealt := target.take_damage(BattleUnit.damage_bonus(caster, target, hit), wrack, damage_type)
	BattleUnit.gambit_damage_dealt(caster, target, dealt)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
	if not target.alive:
		CodgerFx.reel_in(hook, null, 0.1)
		return
	# Drag it in (held still meanwhile), then stun it where it lands.
	var dest := _pull_destination(caster, target)
	CodgerFx.reel_in(hook, target, PULL_TIME)
	if dest != target.cell:
		target.lock_for(PULL_TIME)
		await target.force_move(dest, PULL_TIME)
	if _alive(target):
		target.stun(stun_duration, caster)


## The farthest targetable enemy in reach.
func _pick_target(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_score := -INF
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not caster._is_valid_target(enemy):
			continue
		var distance := caster.grid.get_distance(caster.cell, enemy.cell)
		if distance > range_cells:
			continue
		var score := float(distance)
		if score > best_score:
			best = enemy
			best_score = score
	return best


## Where the pull leaves `target`: up to pull_cells steps toward Codger, each into the free
## neighbouring cell nearest him (it must be nearer than the last), never his own. Stops
## early when the way is blocked. Units immune to crowd control, or that can't move, stay put.
func _pull_destination(caster: BattleUnit, target: BattleUnit) -> Vector2i:
	if target.is_cc_immune() or target.is_immobile():
		return target.cell
	var grid := caster.grid
	var at := target.cell
	for i in pull_cells:
		var best := at
		var best_distance := grid.get_distance(at, caster.cell)
		var best_world := INF
		for offset in HEX_NEIGHBOURS:
			var next: Vector2i = at + offset
			if not grid.can_place(next) or next == caster.cell:
				continue
			var distance := grid.get_distance(next, caster.cell)
			var world := grid.cell_to_world(next).distance_to(caster.global_position)
			if distance < best_distance or (distance == best_distance and best != at and world < best_world):
				best = next
				best_distance = distance
				best_world = world
		if best == at:
			break
		at = best
	return at

const HEX_NEIGHBOURS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]


## Living enemies (other than `target`) within half a cell of the hook's line.
func _enemies_on_path(caster: BattleUnit, from: Vector2, target: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var to := target.global_position
	var width := caster.grid.cell_spacing() * 0.5
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or enemy == target or not caster._is_valid_target(enemy):
			continue
		var p := Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
		if p.distance_to(enemy.global_position) <= width:
			result.append(enemy)
	return result


## Gives Codger his Charge back when a cast found no legal target once its wind-up ended
## (can_use checked at the start, but the enemy may have died, moved or hidden since), so
## he casts again as soon as one is in reach instead of wasting it.
static func refund(caster: BattleUnit) -> void:
	caster.charge = caster.max_charge
	caster._update_charge_bar()


func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
