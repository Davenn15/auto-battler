class_name FocusBeamGambit
extends Gambit
## BEAM.NG B: channels a damaging beam at the enemy in range that the most of its allies are
## attacking (ties go to the nearest). Over each attack interval the beam deals Damage Share
## of a normal attack, with its passive's distance bonus, and triggers on-hit effects like
## its normal beam does. While the beam is on it, allied attacks on that enemy also deal
## Mark Share of its max health.
##   B1: if the target dies during the beam, BEAM.NG gains a burst of Charge.
##   B2: the beam ricochets to one more nearby enemy.

## Seconds BEAM.NG channels the beam.
@export var duration: float = 4.0
## Share of a normal attack each attack interval of beam deals (1.5 = one and a half).
@export var damage_share: float = 1.5
## Allied attacks on the target deal this share of its max health on top (0.02 = 2%).
@export var mark_share: float = 0.02
## B1: Charge gained if the target dies during the beam. 0 = none.
@export var charge_on_kill: float = 0.0
## B2: how many times the beam ricochets on from its target.
@export var bounces: int = 0
## How close the next enemy must be to ricochet to, in hex cells.
@export var bounce_range_cells: int = 2

const TICK := 0.1


func can_use(caster: BattleUnit) -> bool:
	return _pick_target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var target := _pick_target(caster)
	if target == null:
		return
	caster.show_float_text("Focus Beam", BeamngPassive.LIGHT)
	var mark := FocusMarkStatus.new(caster, mark_share)
	target.add_status(mark)
	var links := BeamLinks.new(caster)
	var beams := {}   # enemy instance id -> its BeamngBeamStatus (used as a damage helper)
	var killed := false
	var elapsed := 0.0
	var tick_left := 0.0
	while elapsed < duration:
		caster.lock_for(0.1)   # channelling: a frame at a time, so it ends cleanly
		await caster.get_tree().physics_frame
		if not _alive(caster) or not caster.is_inside_tree() or not caster.active:
			break
		if not _alive(target):
			killed = true
			break
		var delta := caster.get_physics_process_delta_time()
		elapsed += delta
		var chain: Array = [target]
		for i in bounces:
			var next := BeamLinks.nearest_enemy(caster, chain.back(), bounce_range_cells, chain)
			if next == null:
				break
			chain.append(next)
		links.show(chain, BeamngPassive.COLOR)
		tick_left -= delta
		while tick_left <= 0.0:
			tick_left += TICK
			var share := TICK / caster.get_attack_cooldown()
			for enemy in chain:
				if not _alive(enemy):
					continue
				var beam: BeamngBeamStatus = beams.get(enemy.get_instance_id())
				if beam == null:
					beam = BeamngBeamStatus.new(0.0)
					beam.scale = damage_share
					beam._target = enemy
					beams[enemy.get_instance_id()] = beam
				beam._fire_tick(caster, enemy, share)
	for beam in beams.values():
		if _alive(caster):
			beam._flush(caster)   # the last partial attack's effects
	links.clear()
	if is_instance_valid(target) and target.statuses.has(mark):
		target.remove_status(mark)
	if killed and charge_on_kill > 0.0 and _alive(caster):
		caster.charge = minf(caster.charge + charge_on_kill, caster.max_charge)
		caster._update_charge_bar()
		caster.show_float_text("+%d Charge" % roundi(charge_on_kill), BeamngPassive.LIGHT)


## The enemy in attack range that the most allies are attacking; ties go to the nearest.
func _pick_target(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_count := -1
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == caster.team or not enemy.is_targetable():
			continue
		var distance := caster.grid.get_distance(caster.cell, enemy.cell)
		if distance > caster.attack_range:
			continue
		var count := 0
		for other in caster.get_tree().get_nodes_in_group("units"):
			var ally := other as BattleUnit
			if ally != null and ally != caster and ally.alive and ally.team == caster.team and ally.target == enemy:
				count += 1
		if count > best_count or (count == best_count and distance < caster.grid.get_distance(caster.cell, best.cell)):
			best = enemy
			best_count = count
	return best


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


## On the Focus Beam's target: BEAM.NG's allies' attacks on it deal a share of its max
## health on top.
class FocusMarkStatus extends Status:
	var caster   # untyped: may be freed
	var team: int
	var share: float

	func _init(p_caster: BattleUnit, p_share: float) -> void:
		caster = p_caster
		team = p_caster.team
		share = p_share

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_attacked(unit: BattleUnit, attacker: BattleUnit, dealt: float) -> void:
		if dealt <= 0.0 or not is_instance_valid(attacker) or attacker.team != team or attacker == caster \
				or not unit.alive:
			return
		var extra := unit.take_damage(unit.max_health * share, 0, attacker.get_attack_damage_type(), false, attacker, false)
		unit.get_tree().call_group("damage_tracker", "record_damage", attacker.get_credit_id(), extra)
