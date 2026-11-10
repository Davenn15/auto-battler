class_name ClampGambit
extends Gambit
## Grouser B (Clamped): clamps his claw on his target, dealing damage and shredding all its
## wards. Then neither of them can attack, move or cast until the clamp lets go.
## Damage = Damage + Might Scaling x Might.
##   B1: he gains a shield as he casts.

@export var damage: float = 80.0
@export var might_scaling: float = 1.0
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## Ward taken from each of the target's wards, and for how long.
@export var ward_shred: float = 8.0
@export var shred_duration: float = 5.0
## Seconds the clamp holds them both.
@export var hold_time: float = 2.5
## B1: shield as a share of his max health, and how long it lasts. 0 = none.
@export_range(0.0, 1.0, 0.05) var shield_share: float = 0.0
@export var shield_duration: float = 4.0


func can_use(caster: BattleUnit) -> bool:
	return _target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var target := _target(caster)
	if target == null:
		return
	if shield_share > 0.0:
		caster.add_shield(caster.max_health * shield_share, shield_duration, caster.get_instance_id())
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	KeepsakeVfx.claw_snip(target)
	var dealt := target.take_damage(hit, wrack, damage_type, false, caster)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
	for stat in WardShiftStatus.WARDS:
		WardShiftStatus.shred(caster, target, stat, ward_shred, shred_duration)
	caster.show_float_text("Clamp", WardShiftStatus.COLOR)
	if not target.alive:
		return
	if target.is_cc_immune():
		target.show_float_text("Immune", WardShiftStatus.COLOR)
		return
	var hold := hold_time * caster.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, target)
	caster.lock_for(hold)
	target.lock_for(hold)
	var clamp := ClampHold.new()
	clamp.grouser = caster
	clamp.target = target
	clamp.time_left = hold
	clamp.z_index = 12
	caster.get_tree().current_scene.add_child(clamp)


## His current target if it's alive and within his attack range.
func _target(caster: BattleUnit) -> BattleUnit:
	var target := caster.target
	if is_instance_valid(target) and target.alive and target.is_targetable() \
			and caster.grid.get_distance(caster.cell, target.cell) <= caster.attack_range:
		return target
	return null


## Draws the clamp while it holds; lets them both go early if either dies.
class ClampHold extends Node2D:
	var grouser   # untyped: either may be freed
	var target
	var time_left: float
	var _time := 0.0

	func _physics_process(delta: float) -> void:
		time_left -= delta
		var g_alive: bool = is_instance_valid(grouser) and grouser.alive
		var t_alive: bool = is_instance_valid(target) and target.alive
		if time_left <= 0.0 or not g_alive or not t_alive:
			if g_alive and not t_alive:
				grouser._locked_time = 0.0   # nothing left to hold on to
			if t_alive and not g_alive:
				target._locked_time = 0.0
			queue_free()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(grouser) or not is_instance_valid(target):
			return
		var from := to_local(grouser.global_position)
		var to := to_local(target.global_position)
		var color := WardShiftStatus.COLOR
		var shake := Vector2(sin(_time * 40.0), cos(_time * 37.0)) * 1.5   # straining
		draw_line(from, to + shake, Color(color, 0.3), 8.0, true)
		draw_line(from, to + shake, color, 3.0, true)
		# The claw's two jaws gripping the target.
		var dir := (to - from).normalized()
		var side := dir.orthogonal()
		for s: float in [-1.0, 1.0]:
			draw_line(to + shake - dir * 14.0 + side * s * 10.0, to + shake + side * s * 4.0, color, 3.0, true)
		draw_arc(to + shake, 16.0, 0.0, TAU, 24, Color(color, 0.6), 2.0, true)
