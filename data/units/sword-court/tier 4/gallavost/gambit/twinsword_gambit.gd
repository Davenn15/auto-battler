class_name TwinswordGambit
extends Gambit
## Two moves, depending on whether the caster has a shield:
##   Shielded: throws the twinsword out in a line and back, hitting and stunning enemies on
##             each leg. Catching it grants a large shield.
##   Unshielded: twirls in a straight line through the enemy team and back to where it
##             started, hitting enemies on each pass. Shields gained meanwhile arrive after.
## Both aim along the line that passes the most enemies. Damage skips wards while the
## caster has no shield (see PurityStatus).

const BLADE_WIDTH_CELLS := 2.0   # how wide a line counts as "hit", in hex cells
const SPIN_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const SPIN_SPEED := 15.0         # radians per second for the twirl's spinning ring

## How far the throw and the twirl go, in hex cells.
@export var length_cells: int = 4

@export_group("Throw (shielded)")
## Each hit = Throw Damage + Throw Might Scaling x Might.
@export var throw_damage: float = 60.0
@export var throw_might_scaling: float = 0.4
## Seconds each hit stuns.
@export var stun_time: float = 0.6
@export var catch_shield: float = 400.0
## Seconds the caught shield lasts. 0 = for the rest of combat.
@export var catch_shield_duration: float = 0.0
## How big the thrown twinsword is drawn (1 = normal, 1.5 = half again as big).
@export var sword_size: float = 1.0

@export_group("Twirl (unshielded)")
## Each hit = Twirl Damage + Twirl Might Scaling x Might, once per enemy per pass.
@export var twirl_damage: float = 120.0
@export var twirl_might_scaling: float = 0.8
## Pixels per second while twirling.
@export var twirl_speed: float = 360.0
@export_group("Allies (Indestructible)")
## Shield each ally hit by the throw or the twirl gains, once per pass. 0 = none.
@export var ally_shield: float = 0.0
@export var ally_shield_duration: float = 4.0

func can_use(caster: BattleUnit) -> bool:
	return _best_aim(caster)["count"] > 0


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var aim := _best_aim(caster)
	if aim["count"] == 0:
		return
	if caster.get_shield() > 0.0:
		_throw(caster, aim["dir"])
	else:
		await _twirl(caster, aim["dir"])


func _throw(caster: BattleUnit, dir: Vector2) -> void:
	var sword := TwinswordBoomerang.new()
	sword.thrower_id = caster.get_instance_id()
	sword.team = caster.team
	sword.direction = dir
	sword.reach = _length(caster)
	sword.hit_radius = _half_width(caster)
	# Gambit damage can wrack if an item lets it: rolled now, for every hit on both legs.
	sword.wrack_level = caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	sword.damage = Stats.scaled(throw_damage, throw_might_scaling, caster.get_stat(Stats.Stat.MIGHT)) \
			* caster.effect_wrack_multiplier(sword.wrack_level, Stats.EffectKind.GAMBIT_DAMAGE)
	sword.damage_type = caster.get_attack_damage_type()
	sword.ignore_ward = caster.ignores_wards()
	sword.stun_time = stun_time
	sword.catch_shield = catch_shield
	sword.catch_shield_duration = catch_shield_duration if catch_shield_duration > 0.0 else INF
	sword.size = sword_size
	caster.get_tree().current_scene.add_child(sword)
	sword.global_position = caster.global_position
	sword.ally_shield = ally_shield
	sword.ally_shield_duration = ally_shield_duration


## Spins out along `dir` and back, hitting each enemy once per pass. The caster never
## leaves its cell as far as the grid is concerned; only its drawing travels.
func _twirl(caster: BattleUnit, dir: Vector2) -> void:
	var start := caster.global_position
	var far_end := start + dir * _length(caster)
	var hit_damage := Stats.scaled(twirl_damage, twirl_might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	# Gambit damage can wrack if an item lets it: one roll for the whole twirl.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit_damage *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var twirl := TwirlStatus.new()
	caster.add_status(twirl)
	caster.lock_for(2.0 * _length(caster) / twirl_speed + 0.1)
	var spinner := _make_spinner(caster)
	for leg in [[start, far_end], [far_end, start]]:
		var hit := {}   # enemies hit on this pass
		var pos: Vector2 = leg[0]
		while pos != leg[1]:
			if not _alive(caster) or not caster.is_inside_tree():
				break
			# Units run on physics frames, so the twirl does too (and gets a real delta).
			await caster.get_tree().physics_frame
			if not _alive(caster) or not caster.active:
				break
			var delta := caster.get_physics_process_delta_time()
			var next := pos.move_toward(leg[1], twirl_speed * delta)
			_twirl_hits(caster, pos, next, hit_damage, wrack, hit)
			pos = next
			caster.global_position = pos
			if is_instance_valid(spinner):
				spinner.rotation += SPIN_SPEED * delta
	if is_instance_valid(spinner):
		spinner.queue_free()
	# is_inside_tree: the battle may have been cleared mid-twirl, leaving her off the board.
	if _alive(caster) and caster.is_inside_tree():
		caster.global_position = caster.grid.cell_to_world(caster.cell)   # back where it started
		caster.remove_status(twirl)
		if twirl.banked > 0.0:
			caster.add_shield(twirl.banked, INF, caster.get_instance_id())


## A white ring with a gap, spinning around the caster while it twirls. It's as wide as
## the twirl's hits reach, so it also shows what it will hit. A child of the caster, so it
## moves with it and goes away if the caster dies.
func _make_spinner(caster: BattleUnit) -> Line2D:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = SPIN_COLOR
	var r := _half_width(caster)
	var points := PackedVector2Array()
	for i in 25:   # three quarters of a circle, so the spin is visible
		points.append(Vector2.from_angle(TAU * 0.75 * i / 24.0) * r)
	ring.points = points
	ring.z_index = 5
	caster.add_child(ring)
	return ring


func _twirl_hits(caster: BattleUnit, from: Vector2, to: Vector2, amount: float, wrack: int, hit: Dictionary) -> void:
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit == caster or hit.has(unit.get_instance_id()):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(unit.global_position, from, to)
		if closest.distance_to(unit.global_position) > _half_width(caster):
			continue
		hit[unit.get_instance_id()] = true
		if unit.team == caster.team:
			if ally_shield > 0.0:
				unit.add_shield(ally_shield, ally_shield_duration, caster.get_instance_id())
			continue
		var dealt := unit.take_damage(amount, wrack, caster.get_attack_damage_type(), caster.ignores_wards())
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)


## The direction, toward some enemy, whose line passes the most enemies.
## Returns {"dir": Vector2, "count": enemies on it}.
func _best_aim(caster: BattleUnit) -> Dictionary:
	var origin := caster.global_position
	var length := _length(caster)
	var half := _half_width(caster)
	var enemies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team \
				and origin.distance_to(unit.global_position) <= length:
			enemies.append(unit)
	var best := {"dir": Vector2.RIGHT, "count": 0}
	for enemy in enemies:
		var dir: Vector2 = (enemy.global_position - origin).normalized()
		if dir == Vector2.ZERO:
			continue
		var count := enemies.filter(func(e): return SlamGambit.in_rectangle(e.global_position, origin, dir, length, half)).size()
		if count > best["count"]:
			best = {"dir": dir, "count": count}
	return best


func _length(caster: BattleUnit) -> float:
	var spacing := caster.grid.cell_spacing()
	return length_cells * spacing + spacing * 0.5


func _half_width(caster: BattleUnit) -> float:
	return BLADE_WIDTH_CELLS * caster.grid.cell_spacing() * 0.5


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
