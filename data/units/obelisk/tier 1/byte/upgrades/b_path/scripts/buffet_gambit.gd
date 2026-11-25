class_name ByteBuffetGambit
extends Gambit
## Byte B (Buffeting): a blast in a cone Reach Cells long and Cone Degrees wide, aimed where
## it catches the most enemies. Each enemy in it takes Damage (+ Insight Scaling of Byte's
## Insight), loses Might Cut of its Might for Might Cut Duration seconds, and is knocked
## Knockback Cells away from Byte.
##   B1: knocked back further (knockback_cells).
##   B2 (Splash Heal): for each enemy hit, a healing splash heals Splash Heal (+ Splash
##   Insight Scaling of Byte's Insight) to the ally (not Byte) within Splash Range cells of
##   Byte with the lowest health %.
## The cone counts an enemy as in it when it's within Reach Cells and the line to it is
## within half the cone's width of the aim. Ties for the aim go to the cone holding Byte's
## current target, then the nearest enemy, then the lower instance id.

@export var reach_cells: int = 2
@export var cone_degrees: float = 90.0
@export var damage: float = 60.0
@export var insight_scaling: float = 0.3
@export var damage_type: int = Stats.DamageType.INSIGHT
@export_range(0.0, 1.0, 0.05) var might_cut: float = 0.3
@export var might_cut_duration: float = 3.0
@export var knockback_cells: float = 1.0
## B2: 0 = no healing splashes.
@export var splash_heal: float = 0.0
@export var splash_insight_scaling: float = 0.0
@export var splash_range: float = 3.0

const KNOCK_TIME := 0.25


func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_reach(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var in_reach := _enemies_in_reach(caster)
	if in_reach.is_empty():
		return
	var aim := _best_aim(caster, in_reach)
	var hits := _in_cone(caster, in_reach, aim)
	var spacing := caster.grid.cell_spacing()
	ByteFx.cone(caster, aim, (reach_cells + 0.5) * spacing, deg_to_rad(cone_degrees) / 2.0)
	# Farthest first, so the ones behind are out of the way before the near ones are pushed.
	hits.sort_custom(func(a, b):
		var da := caster.global_position.distance_squared_to(a.global_position)
		var db := caster.global_position.distance_squared_to(b.global_position)
		return da > db if da != db else a.get_instance_id() < b.get_instance_id())
	var hit_count := 0
	for node in hits:
		if not is_instance_valid(node) or not node.alive:
			continue
		var enemy: BattleUnit = node
		hit_count += 1
		var hit := Stats.scaled(damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
		var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
		var dealt := enemy.take_damage(BattleUnit.damage_bonus(caster, enemy, hit), wrack, damage_type)
		BattleUnit.gambit_damage_dealt(caster, enemy, dealt)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
		if not enemy.alive:
			continue
		MightCut.apply(enemy, might_cut, might_cut_duration)
		var dest := FlexGambit.knockback_destination(caster, enemy, int(knockback_cells))
		if dest != enemy.cell:
			enemy.lock_for(KNOCK_TIME)
			enemy.force_move(dest, KNOCK_TIME)
	if splash_heal > 0.0:
		for i in hit_count:
			_splash(caster)


## Living, targetable enemies within Reach Cells.
func _enemies_in_reach(caster: BattleUnit) -> Array:
	var result := []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == caster.team or not enemy.is_targetable():
			continue
		if caster.grid.get_distance(caster.cell, enemy.cell) <= reach_cells:
			result.append(enemy)
	return result


## Of the enemies in reach, those inside the cone pointing along `aim`.
func _in_cone(caster: BattleUnit, in_reach: Array, aim: float) -> Array:
	var half := deg_to_rad(cone_degrees) / 2.0 + 0.001
	var result := []
	for enemy in in_reach:
		var to: Vector2 = enemy.global_position - caster.global_position
		if to.length() < 0.5 or absf(angle_difference(aim, to.angle())) <= half:
			result.append(enemy)
	return result


## The aim (pointing at one of the enemies in reach) that puts the most of them in the cone.
func _best_aim(caster: BattleUnit, in_reach: Array) -> float:
	var best_aim := 0.0
	var best_count := -1
	var best_has_target := false
	var best_dist := INF
	var best_id := 0
	for enemy in in_reach:
		var aim: float = (enemy.global_position - caster.global_position).angle()
		var inside := _in_cone(caster, in_reach, aim)
		var count := inside.size()
		var has_target := inside.has(caster.target)
		var dist := caster.global_position.distance_to(enemy.global_position)
		var id: int = enemy.get_instance_id()
		var better := false
		if count != best_count:
			better = count > best_count
		elif has_target != best_has_target:
			better = has_target
		elif not is_equal_approx(dist, best_dist):
			better = dist < best_dist
		else:
			better = id < best_id
		if better:
			best_aim = aim
			best_count = count
			best_has_target = has_target
			best_dist = dist
			best_id = id
	return best_aim


## B2: one healing splash to the ally (not Byte) within Splash Range with the lowest
## health %; ties go to the nearer, then the lower instance id.
func _splash(caster: BattleUnit) -> void:
	var best: BattleUnit = null
	var best_share := INF
	for node in caster.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally == null or ally == caster or not ally.alive or ally.team != caster.team:
			continue
		if caster.grid.get_distance(caster.cell, ally.cell) > int(splash_range):
			continue
		var share := ally.health / ally.max_health if ally.max_health > 0.0 else 1.0
		var better := best == null or share < best_share - 0.0001
		if not better and best != null and absf(share - best_share) <= 0.0001:
			var da := caster.grid.get_distance(caster.cell, ally.cell)
			var db := caster.grid.get_distance(caster.cell, best.cell)
			better = da < db or (da == db and ally.get_instance_id() < best.get_instance_id())
		if better:
			best = ally
			best_share = share
	if best == null:
		return
	ByteFx.splash(caster.global_position, best)
	best.heal(Stats.scaled(splash_heal, splash_insight_scaling, caster.get_stat(Stats.Stat.INSIGHT)), caster.get_credit_id(), true, true)
	BattleUnit.gambit_affected(caster, best)


## Buffeting's debuff: Might lowered by a share for a while. One per unit: applying it again
## refreshes the time and keeps the stronger share. Resisting debuffs shortens it.
class MightCut extends Status:
	var share: float
	var time_left: float

	func _init(p_share: float, p_duration: float) -> void:
		share = p_share
		time_left = p_duration

	static func apply(unit: BattleUnit, p_share: float, duration: float) -> void:
		if not is_instance_valid(unit) or not unit.alive or p_share <= 0.0:
			return
		var time := duration * unit.debuff_multiplier()
		for status in unit.statuses:
			if status is MightCut:
				status.share = maxf(status.share, p_share)
				status.time_left = maxf(status.time_left, time)
				return
		unit.add_status(MightCut.new(p_share, time))
		unit.show_float_text("-%d%% Might" % roundi(p_share * 100.0), ByteFx.LIGHT)

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_final_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value * (1.0 - share) if stat == Stats.Stat.MIGHT else value

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
