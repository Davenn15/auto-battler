class_name CtrlRadarGambit
extends Gambit
## Controller B: a radar pulse. Every enemy within Radius loses Celerity for a while, twice as
## much if it was targeting Controller when the pulse hit.
##   B1: the pulse also cuts their Charge gain, and stops it entirely on enemies that were
##       targeting Controller.
##   B2: a bigger radius.

## How far the pulse reaches, in hex cells.
@export var radius_cells: int = 3
## Celerity taken from each enemy hit (doubled on ones targeting Controller), and for how long.
@export var celerity_cut: float = 25.0
@export var duration: float = 5.0
## B1: share of Charge gain taken away for the same time (0.4 = 40% less); enemies
## targeting Controller gain none. 0 = no Charge effect.
@export_range(0.0, 1.0, 0.05) var charge_cut: float = 0.0

const COLOR := CtrlDrones.COLOR


func can_use(caster: BattleUnit) -> bool:
	return not CtrlDrones.enemies_in_range(caster, radius_cells).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for enemy in CtrlDrones.enemies_in_range(caster, radius_cells):
		var targeting: bool = enemy.target == caster
		var cut := celerity_cut * (2.0 if targeting else 1.0)
		enemy.add_status(TimedStatStatus.new(Stats.Stat.CELERITY, -cut, duration))
		if charge_cut > 0.0:
			enemy.add_status(ChargeJam.new(1.0 if targeting else charge_cut, duration))
		enemy.show_float_text("Jammed" if targeting else "Pinged", COLOR)
	caster.show_float_text("Radar", COLOR)
	if KeepsakeVfx.enabled():
		var pulse := RadarPulse.new()
		pulse.max_radius = (radius_cells + 0.5) * caster.grid.cell_spacing()
		pulse.z_index = 6
		caster.get_parent().add_child(pulse)
		pulse.global_position = caster.global_position


## B1: less Charge gained for a while (none at all at a cut of 1). Wears off sooner on
## units that resist debuffs.
class ChargeJam extends Status:
	var cut: float
	var time_left: float

	func _init(p_cut: float, p_duration: float) -> void:
		cut = p_cut
		time_left = p_duration

	func on_applied(unit: BattleUnit) -> void:
		time_left *= unit.debuff_multiplier()

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return cut >= 1.0

	func modify_charge_gain(_unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 - cut)

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)


## The pulse on screen: a bright wavefront rolling out from Controller to the edge of its
## reach, with fainter echoes trailing behind it, fading as it goes. Purely visual.
class RadarPulse extends Node2D:
	const LIFE := 0.65          # seconds for the front to reach the edge
	const FADE := 0.25          # then this long to fade out there
	const ECHOES := 4
	var max_radius := 100.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		if _time >= LIFE + FADE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var travel := clampf(_time / LIFE, 0.0, 1.0)
		var front := max_radius * ease(travel, 0.6)   # quick off the mark, easing at the edge
		var alpha := 1.0 - clampf((_time - LIFE) / FADE, 0.0, 1.0)
		if front <= 1.0:
			return
		# The wavefront: a soft wide band with a hot thin core.
		draw_arc(Vector2.ZERO, front, 0.0, TAU, 72, Color(COLOR, 0.25 * alpha), 10.0, true)
		draw_arc(Vector2.ZERO, front, 0.0, TAU, 72, Color(COLOR, 0.9 * alpha), 3.0, true)
		draw_arc(Vector2.ZERO, front, 0.0, TAU, 72, Color(CtrlDrones.LIGHT, 0.8 * alpha), 1.2, true)
		# Echoes trailing behind the front, each fainter and further back.
		for i in range(1, ECHOES + 1):
			var r := front - i * 9.0
			if r <= 0.0:
				break
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(COLOR, 0.35 * alpha * (1.0 - float(i) / (ECHOES + 1))), 1.5, true)
