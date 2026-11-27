class_name SegIonGambit
extends Gambit
## Fault: becomes untargetable for Untargetable Time, then teleports to the free cell
## within its attack range of the enemy that has dealt the most damage this combat (the one
## farthest from the other enemies; ties go to the one nearest Fault), and fires an ion
## salvo at it: Bolts bolts, each dealing Damage (+ Insight Scaling of its Insight) as
## Insight damage. The first bolt to land Silences it for Silence Time.
##   A2 (Vulnerability): each Gambit hit leaves a debuff: the target takes +Vulnerability
##   Gambit damage from Fault (and its duplicate) for Vulnerability Duration seconds.
## The hunted enemy is picked when it teleports (ties: nearest, then lower instance id).

@export var untargetable_time: float = 0.75
@export var bolts: int = 4
@export var bolt_gap: float = 0.25   # seconds between bolts
@export var damage: float = 100.0
@export var insight_scaling: float = 0.5
@export var silence_time: float = 2.0
## A2: 0.2 = +20% Gambit damage from Fault while debuffed. 0 = no debuff.
@export var vulnerability: float = 0.0
@export var vulnerability_duration: float = 5.0


func can_use(caster: BattleUnit) -> bool:
	return hunted(caster) != null


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	caster.add_status(UntargetableStatus.new(untargetable_time))
	caster.lock_for(untargetable_time + bolts * bolt_gap)
	if KeepsakeVfx.enabled() and caster.melee_motion != null:
		caster.melee_motion.modulate.a = 0.35   # flickering out
	await caster.get_tree().create_timer(untargetable_time, true, true).timeout
	if not _alive(caster) or not caster.is_inside_tree():
		return
	if caster.melee_motion != null:
		caster.melee_motion.modulate.a = 1.0
	var target := hunted(caster)
	if target == null:
		return
	var old_cell := caster.cell
	var dest := teleport_cell(caster, target)
	if dest != caster.cell:
		var from_pos := caster.global_position
		SegFx.blink(from_pos, caster.get_parent())
		caster.place_at(dest)
		SegFx.teleport_trail(caster.get_parent(), from_pos, caster.global_position)
		SegFx.blink(caster.global_position, caster.get_parent())
		for status in caster.statuses.duplicate():
			if status.has_method("on_seg_teleport"):
				status.on_seg_teleport(caster, old_cell)
	caster.target = target
	var state := {"silenced": false}
	for i in bolts:
		if i > 0:
			await caster.get_tree().create_timer(bolt_gap, true, true).timeout
		if not _alive(caster) or not caster.is_inside_tree() or not _alive(target):
			return
		var bolt := SegFx.IonBolt.new()
		bolt.setup_ion(caster, target, Stats.scaled(damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT)))
		bolt.on_hit = func(t: BattleUnit): _bolt_hit(caster, t, state)
		caster.get_parent().add_child(bolt)
		bolt.global_position = caster.global_position


func _bolt_hit(caster, target: BattleUnit, state: Dictionary) -> void:
	if not _alive(caster) or not _alive(target):
		return
	if not state["silenced"]:
		state["silenced"] = true
		Silence.apply(target, silence_time, caster)
	var hit := Stats.scaled(damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
	hit *= 1.0 + SegVulnerability.bonus_against(target, caster.get_credit_id())
	var wrack: int = caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var dealt := target.take_damage(BattleUnit.damage_bonus(caster, target, hit), wrack, Stats.DamageType.INSIGHT)
	BattleUnit.gambit_damage_dealt(caster, target, dealt)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
	if vulnerability > 0.0 and target.alive:
		SegVulnerability.apply(target, caster.get_credit_id(), vulnerability, vulnerability_duration)


## The living, targetable enemy that has dealt the most damage this combat.
static func hunted(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable():
			continue
		if best == null or unit.damage_dealt > best.damage_dealt:
			best = unit
		elif is_equal_approx(unit.damage_dealt, best.damage_dealt):
			var da := caster.grid.get_distance(caster.cell, unit.cell)
			var db := caster.grid.get_distance(caster.cell, best.cell)
			if da < db or (da == db and unit.get_instance_id() < best.get_instance_id()):
				best = unit
	return best


## The free cell within attack range of `target` farthest from the other enemies (the
## distance to the nearest of them); ties go to the cell nearest Fault. Its own cell
## counts if it's in range. Stays put if there's none.
static func teleport_cell(caster: BattleUnit, target: BattleUnit) -> Vector2i:
	var grid := caster.grid
	var others: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit != target:
			others.append(unit)
	var best := caster.cell
	var best_room := -1
	var best_near := 1 << 30
	for cell in grid.all_cells():
		if grid.get_distance(cell, target.cell) > caster.attack_range or cell == target.cell:
			continue
		if cell != caster.cell and not grid.can_place(cell):
			continue
		var room := 1 << 20
		for other in others:
			room = mini(room, grid.get_distance(cell, other.cell))
		var near := grid.get_distance(cell, caster.cell)
		if room > best_room or (room == best_room and near < best_near):
			best = cell
			best_room = room
			best_near = near
	return best


func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


## A2's debuff: the target takes more Gambit damage from one Fault (by credit id, so its
## duplicate counts too). Hitting again refreshes it.
class SegVulnerability extends Status:
	var source_id: int
	var bonus: float
	var time_left: float

	static func apply(target: BattleUnit, p_source: int, p_bonus: float, duration: float) -> void:
		var time := duration * target.debuff_multiplier()
		for status in target.statuses:
			if status is SegVulnerability and status.source_id == p_source:
				status.bonus = maxf(status.bonus, p_bonus)
				status.time_left = maxf(status.time_left, time)
				return
		var vuln := SegVulnerability.new()
		vuln.source_id = p_source
		vuln.bonus = p_bonus
		vuln.time_left = time
		target.add_status(vuln)

	## The extra Gambit damage share `target` takes from `source_id` right now.
	static func bonus_against(target: BattleUnit, p_source_id: int) -> float:
		for status in target.statuses:
			if status is SegVulnerability and status.source_id == p_source_id:
				return status.bonus
		return 0.0

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
