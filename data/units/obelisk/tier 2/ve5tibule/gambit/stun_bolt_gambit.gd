class_name StunBoltGambit
extends Gambit
## Vestibule's Gambit: sends spiralling stun bolts at the nearest enemies within Range
## Cells (one bolt each; with fewer enemies, fewer bolts).
## Each deals Damage + Insight Scaling x Insight and stuns for Stun Time.
## A2: the bolts also apply his Hit Effects.

@export var bolts: int = 2
## How close the enemies must be, in hex cells.
@export var range_cells: int = 4
@export var damage: float = 70.0
@export var insight_scaling: float = 0.65
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 1
@export var stun_time: float = 1.0
## A2: each bolt applies his Hit Effects to its target.
@export var apply_hit_effects: bool = false

const COLOR := Color(0.55, 0.8, 1.0)


func can_use(caster: BattleUnit) -> bool:
	return not _targets(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var hit := Stats.scaled(damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))   # fixed at launch
	var side := 1.0
	for target in _targets(caster):
		var bolt := StunBolt.new()
		bolt.gambit = self
		bolt.caster_id = caster.get_instance_id()
		bolt.target = target
		bolt.hit = hit
		bolt.spin = side   # the two bolts spiral opposite ways
		side = -side
		caster.get_parent().add_child(bolt)
		bolt.global_position = caster.global_position
		bolt.start = caster.global_position


## The nearest enemies in range (ties go to whoever has dealt more damage this combat), up
## to Bolts of them, skipping any that can't be targeted.
func _targets(caster: BattleUnit) -> Array:
	var found: Array = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable() \
				and caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			found.append(unit)
	found.sort_custom(func(a, b):
		var da: int = caster.grid.get_distance(caster.cell, a.cell)
		var db: int = caster.grid.get_distance(caster.cell, b.cell)
		if da != db:
			return da < db
		return a.damage_dealt > b.damage_dealt)
	return found.slice(0, maxi(bolts + ExtraVolleyEffect.extra_on(caster), 0))   # Redundancy: one more


## The bolt landing: damage (it can Wrack as Gambit damage), a stun, and with A2 his Hit Effects.
func land(caster: BattleUnit, target: BattleUnit, hit: float) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	var wrack := 0
	if is_instance_valid(caster):
		wrack = caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var dealt := target.take_damage(BattleUnit.damage_bonus(caster, target, hit), wrack, damage_type)
	if is_instance_valid(caster):
		BattleUnit.gambit_damage_dealt(caster, target, dealt)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
	if target.alive:
		target.stun(stun_time, caster if is_instance_valid(caster) else null)
	if apply_hit_effects and is_instance_valid(caster) and caster.alive and dealt > 0.0:
		var effects: Array[HitEffect] = []
		for status in caster.statuses.duplicate():
			var effect: HitEffect = status.get_hit_effect(caster)
			if effect != null:
				effects.append(effect)
		BattleUnit.run_hit_effects(effects, target, dealt, wrack)


## A bolt in flight: homes in on its target, spiralling around the straight line there, and
## lands when it reaches it. Fizzles if the target dies first.
class StunBolt extends Node2D:
	const SPEED := 330.0   # pixels per second along the way
	const SWIRL := 14.0    # how far it swings out from the straight line
	var gambit: StunBoltGambit
	var caster_id := 0
	var target   # untyped: may be freed
	var hit := 0.0
	var spin := 1.0
	var start := Vector2.ZERO
	var _travelled := 0.0
	var _trail: Array[Vector2] = []

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(target) or not target.alive:
			queue_free()
			return
		var to: Vector2 = target.global_position - start
		var length := maxf(to.length(), 1.0)
		_travelled += SPEED * delta
		var t := clampf(_travelled / length, 0.0, 1.0)
		var along := start + to * t
		var swirl := sin(t * TAU * 1.5) * SWIRL * (1.0 - t) * spin
		global_position = along + to.normalized().orthogonal() * swirl
		_trail.push_front(global_position)
		if _trail.size() > 8:
			_trail.pop_back()
		queue_redraw()
		if t >= 1.0:
			gambit.land(instance_from_id(caster_id) as BattleUnit, target, hit)
			if KeepsakeVfx.enabled():
				KeepsakeVfx.burst(target, StunBoltGambit.COLOR)
			queue_free()

	func _draw() -> void:
		for i in range(_trail.size() - 1):
			var fade := 1.0 - float(i) / _trail.size()
			draw_line(_trail[i] - global_position, _trail[i + 1] - global_position, Color(StunBoltGambit.COLOR, 0.6 * fade), 3.0 * fade + 1.0, true)
		draw_circle(Vector2.ZERO, 6.0, Color(StunBoltGambit.COLOR, 0.35))
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 1.0, 1.0, 0.95))
