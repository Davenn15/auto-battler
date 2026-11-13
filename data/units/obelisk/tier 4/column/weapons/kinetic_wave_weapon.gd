class_name ColumnKineticWaveWeapon
extends ColumnWeapon
## A1: sends a wave of kinetic energy in a straight line (the one hitting the most enemies),
## damaging and stunning every enemy it passes through.
## Damage = Damage + Might Scaling x Might.

@export var length_cells: int = 4
## How wide the wave is, in cells.
@export var width_cells: float = 1.5
@export var damage: float = 30.0
@export var might_scaling: float = 0.4
@export var stun_time: float = 1.0


func fire(unit: BattleUnit) -> bool:
	var dir := ColumnWeapon.best_line(unit, length_cells, width_cells)
	if dir == Vector2.ZERO:
		return false
	var hit := Stats.scaled(damage, might_scaling, unit.get_stat(Stats.Stat.MIGHT))
	var level := unit.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= unit.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
	for enemy in ColumnWeapon.enemies_on_line(unit, dir, length_cells, width_cells):
		var dealt := enemy.take_damage(hit, level, Stats.DamageType.MIGHT, false, unit)
		unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
		if enemy.alive:
			enemy.stun(stun_time, unit)
	_show(unit, dir)
	return true


func _show(unit: BattleUnit, dir: Vector2) -> void:
	if not KeepsakeVfx.enabled():
		return
	var wave := Wave.new()
	wave.reach = (length_cells + 0.5) * unit.grid.cell_spacing()
	wave.width = width_cells * unit.grid.cell_spacing()
	wave.z_index = 13
	unit.get_parent().add_child(wave)
	wave.global_position = unit.global_position
	wave.global_rotation = dir.angle()


## A neon lime wall of digital energy sweeping out along the line: a bright curved front
## built from glowing bars, broken into scanlines, with pixel blocks flickering in its wake.
class Wave extends Node2D:
	const LIFE := 0.55
	const NEON := Color(0.7, 1.0, 0.15)
	var reach := 200.0
	var width := 80.0
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	## A repeatable "random" number from 0 to 1 (looks only).
	func _noise(a: float, b: float) -> float:
		return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

	func _draw() -> void:
		var t := _age / LIFE
		var x := reach * minf(t * 1.25, 1.0)
		var fade := clampf((1.0 - t) * 1.6, 0.0, 1.0)
		var half := width * 0.5
		# The trail: a faint band from COLUMN to the front.
		draw_rect(Rect2(0, -half * 0.8, x, half * 1.6), Color(NEON, 0.08 * fade))
		# The front: a curved wall of short bars, each a scanline, bowing forward.
		var rows := 14
		for i in rows:
			var y := -half + width * (i + 0.5) / rows
			var bow := 10.0 * (1.0 - pow(y / half, 2.0))   # the middle leads
			if _noise(i, floorf(_age * 30.0)) < 0.12:
				continue   # a flickering gap, like a glitch
			var front := x + bow
			draw_line(Vector2(front - 26.0, y), Vector2(front, y), Color(NEON, 0.35 * fade), width / rows * 0.9)
			draw_line(Vector2(front - 8.0, y), Vector2(front + 2.0, y), Color(1.0, 1.0, 0.85, 0.95 * fade), width / rows * 0.6)
		# Pixel blocks left in its wake.
		var tick := floorf(_age * 24.0)
		for b in 18:
			var bx := x * _noise(b, 3.0) - 20.0 * _noise(b, tick)
			if bx < 0.0:
				continue
			var by := (_noise(b + 5.0, 7.0) - 0.5) * width
			var size := 3.0 + 4.0 * _noise(b, 11.0)
			draw_rect(Rect2(bx, by, size, size), Color(NEON, 0.6 * fade * _noise(b + 1.0, tick)))
		# Bright edges along the top and bottom of the band.
		draw_line(Vector2(0, -half), Vector2(x, -half), Color(NEON, 0.25 * fade), 2.0)
		draw_line(Vector2(0, half), Vector2(x, half), Color(NEON, 0.25 * fade), 2.0)
