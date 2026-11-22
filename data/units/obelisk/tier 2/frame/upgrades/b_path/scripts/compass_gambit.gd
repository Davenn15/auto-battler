class_name CompassGambit
extends Gambit
## FRAME B (Compassing): stretches its legs extra long and strides into the space of the ally
## with the highest Celerity within Reach Cells, looming over it for Duration seconds: FRAME
## shares the ally's cell (drawn behind it, towering over it) and moves with it. Meanwhile
## the ally gains Celerity Share of FRAME's Celerity, and whenever the ally attacks, FRAME
## attacks the same target (wherever it is). FRAME makes no attacks of its own and gains no
## Charge meanwhile. Enemies can still target and hit FRAME there, as normal. When it
## ends, FRAME steps out to the free cell nearest the ally.
##   B1: the ally also has Immovability meanwhile.
##   B2: FRAME can gain Charge (and so cast again) meanwhile.

@export var reach_cells: int = 4
@export var duration: float = 4.0
@export_range(0.0, 1.0, 0.05) var celerity_share: float = 0.35
## B1: Immovability the ally has while followed. 0 = none.
@export var immovability: float = 0.0
## B2: 1 = FRAME can gain Charge while following.
@export var can_charge: float = 0.0

const STRIDE_TIME := 0.3
## How far FRAME's health plate floats above its normal spot while looming, so it doesn't
## cover the ally's plate (its stretched legs lift its head about this much too).
const LOOM_PLATE_LIFT := 34.0


func can_use(caster: BattleUnit) -> bool:
	return _fastest_ally(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var ally := _fastest_ally(caster)
	if ally == null:
		return
	for status in caster.statuses.duplicate():
		if status is FollowStatus:
			status.end(caster, false)   # a new partner replaces the old one: no stepping out
	var follow := FollowStatus.new(self, ally)
	caster.add_status(follow)
	var followed := FollowedStatus.new(self, caster)
	follow.followed = followed
	ally.add_status(followed)
	caster.show_float_text("Compassing", FrameFx.LIGHT)


## The living ally (not FRAME) with the most Celerity within Reach Cells; ties go to the
## nearer, then the lower instance id.
func _fastest_ally(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally == null or ally == caster or not ally.alive or ally.team != caster.team:
			continue
		if caster.grid.get_distance(caster.cell, ally.cell) > reach_cells:
			continue
		if best == null or ally.get_stat(Stats.Stat.CELERITY) > best.get_stat(Stats.Stat.CELERITY):
			best = ally
		elif is_equal_approx(ally.get_stat(Stats.Stat.CELERITY), best.get_stat(Stats.Stat.CELERITY)):
			var da := caster.grid.get_distance(caster.cell, ally.cell)
			var db := caster.grid.get_distance(caster.cell, best.cell)
			if da < db or (da == db and ally.get_instance_id() < best.get_instance_id()):
				best = ally
	return best


## Steps FRAME out of the shared space to the free cell nearest `around` (the cell itself
## if it's free now, e.g. the ally died), sliding there over STRIDE_TIME. Ties go to the cell
## nearest FRAME on screen, then the first found.
static func step_out(frame: BattleUnit, around: Vector2i) -> void:
	var grid := frame.grid
	for radius in range(0, 12):
		var best := Vector2i.ZERO
		var best_d := INF
		for cell in grid.free_cells_in_range(around, radius):
			var d := grid.cell_to_world(cell).distance_to(frame.global_position)
			if d < best_d:
				best_d = d
				best = cell
		if best_d < INF:
			frame.lock_for(STRIDE_TIME)
			if best == frame.cell:
				var at := frame.global_position
				frame.place_at(best)   # claims the cell it's already standing in
				frame.global_position = at
				frame.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) \
					.tween_property(frame, "global_position", grid.cell_to_world(best), STRIDE_TIME)
			else:
				frame.dash_to(best, STRIDE_TIME)
			return


## On FRAME: looms over the ally in its cell, no attacks of its own, no walking of its own.
## While looming FRAME holds no cell on the grid (the ally does); its `cell` just tracks the
## ally's, so range, targeting and pathing treat it as standing there.
class FollowStatus extends Status:
	var gambit: CompassGambit
	var ally   # untyped: may be freed
	var followed: Status
	var time_left: float
	var _ally_cell := Vector2i.ZERO   # the ally's last cell, for stepping out if it's gone
	var _slide_left := 0.0            # the stride in: sliding from where FRAME was
	var _slide_from := Vector2.ZERO
	var _step_out := true             # false when a new Compassing replaces this one
	var _lifted = null   # the ally drawn a level up while FRAME looms behind it (may be freed)
	const END_DELAY := 0.5   # FRAME's first own attack comes at least this long after following

	func _init(p_gambit: CompassGambit, p_ally: BattleUnit) -> void:
		gambit = p_gambit
		ally = p_ally
		time_left = p_gambit.duration

	func on_applied(unit: BattleUnit) -> void:
		FrameFx.stretch(unit, 1.6)   # legs out extra long
		if unit._moving:   # drop any step it was taking, as a forced move would
			if not unit._step_switched:
				unit.grid.vacate(unit._dest_cell, unit)
			unit._moving = false
		unit.grid.vacate(unit.cell, unit)   # the ally holds the shared cell
		_ally_cell = ally.cell
		unit.cell = ally.cell
		_slide_from = unit.global_position
		_slide_left = CompassGambit.STRIDE_TIME
		unit.lock_for(CompassGambit.STRIDE_TIME)
		# The ally is lifted one drawing level, so FRAME is drawn behind it. (FRAME can't
		# drop a level itself: the board's cells are drawn at its normal level.)
		ally.z_index += 1
		_lifted = ally
		unit.set_plate_lift(CompassGambit.LOOM_PLATE_LIFT)

	func on_removed(unit: BattleUnit) -> void:
		FrameFx.stretch(unit, 1.0)
		if is_instance_valid(_lifted):
			_lifted.z_index -= 1
		_lifted = null
		unit.set_plate_lift(0.0)
		_release_ally()
		if _step_out and unit.alive and unit.is_inside_tree() and unit.grid.unit_at(unit.cell) != unit:
			CompassGambit.step_out(unit, ally.cell if is_instance_valid(ally) else _ally_cell)

	## FRAME died: the partner loses everything FRAME was giving it, right away.
	func on_death(unit: BattleUnit) -> void:
		end(unit)

	## Takes the partner's half (Celerity share, B1's Immovability) off it, however the
	## follow ends (time up, partner died, FRAME died, recast, cleansed).
	func _release_ally() -> void:
		if is_instance_valid(ally) and followed != null and ally.statuses.has(followed):
			ally.remove_status(followed)

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return gambit.can_charge <= 0.0

	func blocks_attacks(_unit: BattleUnit) -> bool:
		return true

	func blocks_movement(_unit: BattleUnit) -> bool:
		return true   # it strides after its partner instead

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0 or not is_instance_valid(ally) or not ally.alive:
			end(unit)
			return
		_mirror_attack_timer(unit)
		_loom(unit, delta)

	## Keeps FRAME in the ally's cell and on top of it (sliding in at first). If something
	## shoved FRAME into a cell of its own (a knockback, a pull), it lets that cell go again.
	func _loom(unit: BattleUnit, delta: float) -> void:
		if unit.grid.unit_at(unit.cell) == unit and unit.cell != ally.cell:
			unit.grid.vacate(unit.cell, unit)
		_ally_cell = ally.cell
		unit.cell = ally.cell
		if _slide_left > 0.0:
			_slide_left = maxf(_slide_left - delta, 0.0)
			var t := 1.0 - _slide_left / CompassGambit.STRIDE_TIME
			unit.global_position = _slide_from.lerp(ally.global_position, t)
		else:
			unit.global_position = ally.global_position

	## FRAME attacks when its partner does, so its attack timer shows the partner's: the
	## partner's own timer, or for a Beam partner the time until its next 4th tick. (FRAME
	## never attacks off this timer itself; blocks_attacks stops that.)
	func _mirror_attack_timer(unit: BattleUnit) -> void:
		var total: float = ally.get_attack_cooldown()
		if Beam.has_attack_beam(ally) and followed != null:
			unit._attack_cooldown_total = total
			unit._attack_timer = clampf(followed.beam_time_left(Beam.tick_interval(total)), 0.001, total)
		else:
			unit._attack_cooldown_total = ally._attack_cooldown_total if ally._attack_cooldown_total > 0.0 else total
			unit._attack_timer = maxf(ally._attack_timer, 0.001)

	func end(unit: BattleUnit, step_out: bool = true) -> void:
		_step_out = step_out
		# Back on its own timer, at least END_DELAY from its next attack (as before the
		# timer mirrored its partner's).
		var own := unit.get_attack_cooldown()
		unit._attack_cooldown_total = own
		unit._attack_timer = clampf(unit._attack_timer, minf(END_DELAY, own), own)
		unit.remove_status(self)   # on_removed takes the partner's half off too
		_release_ally()


## On the ally: FRAME's Celerity share (and B1's Immovability); FRAME strikes its target
## whenever it attacks.
class FollowedStatus extends Status:
	var gambit: CompassGambit
	var frame   # untyped: may be freed

	func _init(p_gambit: CompassGambit, p_frame: BattleUnit) -> void:
		gambit = p_gambit
		frame = p_frame

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if not is_instance_valid(frame) or not frame.alive:
			return value
		if stat == Stats.Stat.CELERITY:
			return value + frame.get_stat(Stats.Stat.CELERITY) * gambit.celerity_share
		if stat == Stats.Stat.IMMOVABILITY:
			return value + gambit.immovability
		return value

	## Beam partners: ticks counted toward FRAME's next attack, how long since the last
	## one, and the gap between the last two (to show FRAME's attack timer).
	var _ticks := 0
	var _since_tick := 0.0
	var _tick_gap := 0.0

	func on_attack(unit: BattleUnit) -> void:
		if Beam.flushing:
			return   # a Beam partner: FRAME counts its ticks instead (on_beam_tick)
		_strike(unit.attack_target)

	## FRAME attacks once every Beam.TICKS_PER_ATTACK ticks of the partner's Beams (so once
	## per attack's worth, whatever makes the Beam trigger effects more often).
	func on_beam_tick(_unit: BattleUnit, enemy: BattleUnit) -> void:
		if _since_tick > 0.0:
			_tick_gap = _since_tick
		_since_tick = 0.0
		_ticks += 1
		if _ticks >= Beam.TICKS_PER_ATTACK:
			_ticks = 0
			_strike(enemy)

	func tick(_unit: BattleUnit, delta: float) -> void:
		_since_tick += delta

	func _strike(target) -> void:
		if is_instance_valid(frame) and frame.alive and frame.active and is_instance_valid(target) and target.alive:
			frame.attack_now(target)

	## Seconds until FRAME's next attack with a Beam partner, judged from its tick rhythm
	## (`fallback_gap` until two ticks have come in).
	func beam_time_left(fallback_gap: float) -> float:
		var gap := _tick_gap if _tick_gap > 0.0 else fallback_gap
		var left := (Beam.TICKS_PER_ATTACK - _ticks - 1) * gap + maxf(gap - _since_tick, 0.0)
		return clampf(left, 0.0, gap * Beam.TICKS_PER_ATTACK)
