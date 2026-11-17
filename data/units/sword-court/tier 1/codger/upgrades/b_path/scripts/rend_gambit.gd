class_name RendGambit
extends Gambit
## Codger B: rends his target with his bladehook for Damage + Might Scaling x Might, then
## leaves it bleeding for Bleed Per Second over Bleed Duration (bleeds skip wards). Casting
## again on a target that's still bleeding restarts its bleed.
##   B1: if the target dies to the hit, or at any point while the bleed is ticking, Codger
##       gains a stack of Glory (base attributes and Wards +5% for the rest of the match).
##   B2: shields and healing on the target are Heal Cut less effective while it bleeds.

@export var damage: float = 120.0
@export var might_scaling: float = 1.0
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
@export var bleed_per_second: float = 40.0
@export var bleed_duration: float = 4.0
## B1: 1 = a death to the hit or while bleeding gives Codger a stack of Glory.
@export var glory_on_kill: float = 0.0
## B2: share taken off shields and healing on the bleeding target (0.4 = 40% less).
@export var heal_cut: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return _pick_target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var target := _pick_target(caster)
	if target == null:
		BladehookGambit.refund(caster)   # its target died or left reach during the wind-up
		return
	CodgerFx.rend(caster.get_parent(), caster.global_position, target.global_position)
	# The bleed goes on first, so a kill by the hit itself counts for B1.
	RendBleed.apply(target, caster, self)
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var dealt := target.take_damage(BattleUnit.damage_bonus(caster, target, hit), wrack, damage_type)
	BattleUnit.gambit_damage_dealt(caster, target, dealt)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)


## His target if it's in attack range, otherwise the nearest enemy in attack range.
func _pick_target(caster: BattleUnit) -> BattleUnit:
	if caster._is_valid_target(caster.target) \
			and caster.grid.get_distance(caster.cell, caster.target.cell) <= caster.attack_range:
		return caster.target
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not caster._is_valid_target(enemy):
			continue
		var distance := caster.grid.get_distance(caster.cell, enemy.cell)
		if distance <= caster.attack_range and (best == null or distance < caster.grid.get_distance(caster.cell, best.cell)):
			best = enemy
	return best


## Rend's bleed on its target: damage over time that skips wards, B2's cut to shields and
## healing, and B1's Glory if the target dies while it's on. One per Codger per target.
class RendBleed extends Status:
	const BLEED_COLOR := Color(0.75, 0.1, 0.1)
	var codger   # untyped: may be freed
	var source_id: int
	var damage_per_second: float
	var time_left: float
	var glory: bool
	var cut: float

	static func apply(target: BattleUnit, caster: BattleUnit, gambit: RendGambit) -> void:
		for status in target.statuses:
			if status is RendBleed and status.source_id == caster.get_instance_id():
				status.damage_per_second = gambit.bleed_per_second
				status.time_left = gambit.bleed_duration
				return
		var bleed := RendBleed.new()
		bleed.codger = caster
		bleed.source_id = caster.get_instance_id()
		bleed.damage_per_second = gambit.bleed_per_second
		bleed.time_left = gambit.bleed_duration
		bleed.glory = gambit.glory_on_kill > 0.0
		bleed.cut = gambit.heal_cut
		target.add_status(bleed)
		target.show_float_text("Bleeding", BLEED_COLOR)

	func on_applied(unit: BattleUnit) -> void:
		if glory:
			unit.died.connect(_on_died)

	func on_removed(unit: BattleUnit) -> void:
		if unit.died.is_connected(_on_died):
			unit.died.disconnect(_on_died)

	func _on_died(_unit: BattleUnit) -> void:
		if is_instance_valid(codger) and codger.alive:
			codger.gain_glory()

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		var step := minf(delta, time_left)
		time_left -= delta
		var dealt := unit.take_warded_damage(BattleUnit.damage_bonus(source_id, unit, damage_per_second * step))
		unit.add_running_damage("rend_%d" % source_id, dealt, BLEED_COLOR)
		unit.get_tree().call_group("damage_tracker", "record_damage", source_id, dealt)
		if unit.alive and time_left <= 0.0:
			unit.remove_status(self)

	func modify_healing_received(_unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 - cut)

	func modify_shield_received(_unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 - cut)
