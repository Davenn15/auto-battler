class_name WindupGambit
extends Gambit
## Mallet B (Pinpoint): gains a shield and winds up, spinning faster and faster. When the
## shield breaks, or Max Windup runs out, it flies to the enemy with the highest Insight
## and smashes it, dealing massive damage and stunning it. Any shield left ends at launch.
## Damage = (Damage + Might Scaling x Might) x (1 + Bonus Per Second x seconds wound up).
##   B2: if the hit deals damage, it consumes all its Keepsakes (loose Shards too) for the
##       rest of the battle; each one adds Keepsake Bonus damage to that hit and gives
##       Keepsake Charge back.

@export_range(0.0, 1.0, 0.05) var shield_share: float = 0.3   # of max health
## Most seconds it winds up before launching on its own.
@export var max_windup: float = 4.0
@export var damage: float = 200.0
@export var might_scaling: float = 1.2
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## Extra damage per second spent winding up (0.5 = +50% per second).
@export var bonus_per_second: float = 0.5
@export var stun_time: float = 1.5
## Seconds the flight takes (untargetable).
@export var flight_time: float = 0.35
@export var leap_height: float = 36.0
## B2: 1 = a hit that deals damage consumes all its Keepsakes (loose Shards too) for the
## rest of the battle.
@export var consume_keepsakes: float = 0.0
## B2: extra damage per Keepsake consumed (0.25 = +25% each).
@export var keepsake_bonus: float = 0.0
## B2: Charge it gets back per Keepsake consumed.
@export var keepsake_charge: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return _pick_target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	caster.add_shield(caster.max_health * shield_share, max_windup + 1.0, caster.get_instance_id(), true, true)
	var shield: ShieldStatus = null
	if not caster.statuses.is_empty() and caster.statuses.back() is ShieldStatus:
		shield = caster.statuses.back()
	caster.show_float_text("Winding up", MalletFx.LIGHT)
	var spin := WindupSpin.new()
	spin.z_index = 12
	caster.add_child(spin)
	var wound := 0.0
	while wound < max_windup:
		caster.lock_for(0.1)   # a frame at a time, so launching early leaves no lock behind
		await caster.get_tree().physics_frame
		if not _alive(caster) or not caster.is_inside_tree() or not caster.active:
			if is_instance_valid(spin):
				spin.queue_free()
			if is_instance_valid(caster) and caster.melee_motion != null:
				caster.melee_motion.rotation = 0.0
			return
		var delta := caster.get_physics_process_delta_time()
		wound += delta
		spin.progress = wound / max_windup
		_spin_body(caster, spin.progress, delta)
		if shield != null and (shield.shield <= 0.0 or not caster.statuses.has(shield)):
			break   # the shield broke: launch now
	spin.queue_free()
	if shield != null and caster.statuses.has(shield):
		caster.remove_status(shield)
	await _launch(caster, wound)


func _launch(caster: BattleUnit, wound: float) -> void:
	var target := _pick_target(caster)
	if target == null:
		if caster.melee_motion != null:
			caster.melee_motion.rotation = 0.0
		return
	caster.target = target
	await MalletFx.rocket(caster, _landing_cell(caster, target), target, flight_time)
	if not _alive(caster) or not caster.active or not caster.is_inside_tree() or not _alive(target):
		return
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	hit *= 1.0 + bonus_per_second * wound
	var held := caster.keepsakes.size() if consume_keepsakes > 0.0 else 0
	hit *= 1.0 + keepsake_bonus * held
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	KeepsakeVfx.missile_blast(caster.get_parent(), target.global_position, 40.0, MalletFx.COLOR)
	var dealt := MalletSlamGambit.hit_enemy(caster, target, hit, wrack, damage_type, 0.0)
	if dealt > 0.0 and target.alive and stun_time > 0.0:
		target.stun(stun_time, caster)
	if dealt > 0.0 and held > 0 and _alive(caster):
		_consume_keepsakes(caster)


## B2: eats every Keepsake it holds for the rest of the battle, with Charge back for each.
## The Charge lands as a burst, like a refund, even mid-Gambit.
func _consume_keepsakes(caster: BattleUnit) -> void:
	var eaten := caster.keepsakes.duplicate()
	for keepsake in eaten:
		caster.swap_keepsake_in_combat(null, keepsake)
	caster.show_float_text("Consumed %d" % eaten.size() if eaten.size() > 1 else "Consumed " + eaten[0].keepsake_name, MalletFx.LIGHT)
	if keepsake_charge > 0.0 and caster.gambit != null:
		caster.charge = minf(caster.charge + keepsake_charge * eaten.size(), caster.max_charge)
		caster._update_charge_bar()


## The enemy with the highest Insight (ties go to the nearest).
func _pick_target(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable():
			continue
		if best == null:
			best = unit
			continue
		var insight := unit.get_stat(Stats.Stat.INSIGHT)
		var best_insight := best.get_stat(Stats.Stat.INSIGHT)
		var nearer := caster.grid.get_distance(caster.cell, unit.cell) < caster.grid.get_distance(caster.cell, best.cell)
		if insight > best_insight or (is_equal_approx(insight, best_insight) and nearer):
			best = unit
	return best


## Where to land: its own cell if it's already next to the target, else the free cell next
## to the target nearest to it (or stay put if there's none).
func _landing_cell(caster: BattleUnit, target: BattleUnit) -> Vector2i:
	var grid := caster.grid
	if grid.get_distance(caster.cell, target.cell) <= 1:
		return caster.cell
	var cells := grid.free_cells_in_range(target.cell, 1)
	if cells.is_empty():
		return caster.cell
	cells.sort_custom(func(a, b): return grid.get_distance(caster.cell, a) < grid.get_distance(caster.cell, b))
	return cells[0]


## Mallet's whole body spinning, faster and faster as it winds up (SPIN_START to SPIN_END
## radians a second). It turns the unit's MeleeMotion node, which nothing else turns, so
## it never fights other animations; shots still hit it as it stands (SpriteEdge).
const SPIN_START := 3.0
const SPIN_END := 45.0

func _spin_body(caster: BattleUnit, progress: float, delta: float) -> void:
	if not KeepsakeVfx.enabled() or caster.melee_motion == null:
		return
	var speed := lerpf(SPIN_START, SPIN_END, progress * progress)
	caster.melee_motion.rotation = wrapf(caster.melee_motion.rotation + speed * delta, -PI, PI)


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


## Crimson arcs whirling around Mallet, faster and brighter as it winds up.
class WindupSpin extends Node2D:
	var progress := 0.0
	var _angle := 0.0

	func _process(delta: float) -> void:
		_angle += delta * lerpf(4.0, 30.0, progress * progress)
		queue_redraw()

	func _draw() -> void:
		var radius := 26.0
		var color := MalletFx.COLOR.lerp(MalletFx.LIGHT, progress)
		for i in 3:
			var start := _angle + TAU * i / 3.0
			draw_arc(Vector2.ZERO, radius, start, start + 1.2, 12, Color(color, 0.85), 3.0 + 3.0 * progress, true)
