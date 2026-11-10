class_name SeedStatus
extends Status
## A replication seed growing in an ally. Hatches into duplicates of REPL\K8R after its
## gestation, or at once if the ally dies.

var tmpl: Dictionary
var gestation: float = 8.0
var hatch_count: int = 2
var min_share: float = 0.15
var max_share: float = 0.5
var _time := 0.0
var _hatched := false
var _host   # untyped: may be freed
var _mark: SeedMark


static func has_seed(unit: BattleUnit) -> bool:
	for status in unit.statuses:
		if status is SeedStatus:
			return true
	return false


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func on_applied(unit: BattleUnit) -> void:
	_host = unit
	unit.died.connect(_on_host_died)
	_mark = SeedMark.new()
	_mark.seed = self
	_mark.z_index = 13
	unit.add_child(_mark)
	_mark.position = Vector2(20, 14)   # beside the host, clear of icons over its head


func on_removed(unit: BattleUnit) -> void:
	if unit.died.is_connected(_on_host_died):
		unit.died.disconnect(_on_host_died)
	if is_instance_valid(_mark):
		_mark.queue_free()


func progress() -> float:
	return clampf(_time / gestation, 0.0, 1.0) if gestation > 0.0 else 1.0


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active:
		unit.remove_status(self)
		return
	_time += delta
	if _time >= gestation:
		_hatch(unit)
		unit.remove_status(self)


func _on_host_died(unit: BattleUnit) -> void:
	_hatch(unit)


func _hatch(host: BattleUnit) -> void:
	if _hatched:
		return
	_hatched = true
	var hp: float = tmpl["full_health"] * lerpf(min_share, max_share, progress())
	var cells := Replicator.free_cells_near(host.grid, host.cell, hatch_count)
	KeepsakeVfx.missile_blast(host.get_parent(), host.global_position, 44.0, Replicator.COLOR)
	for cell in cells:
		Replicator.spawn(tmpl, cell, [], hp, hp)


## The seed drawn on its host: a green seed that swells, ringed by how far along it is.
class SeedMark extends Node2D:
	var seed: SeedStatus
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if seed == null:
			return
		var p := seed.progress()
		var pulse := 1.0 + 0.12 * sin(_time * (4.0 + 8.0 * p))
		var size := (6.0 + 5.0 * p) * pulse
		draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.45))   # dark backing so it reads
		draw_circle(Vector2.ZERO, size + 3.0, Color(Replicator.COLOR, 0.4))
		draw_circle(Vector2.ZERO, size, Replicator.COLOR)
		draw_circle(Vector2(-size * 0.3, -size * 0.3), size * 0.35, Color(Replicator.LIGHT, 0.8))
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(Replicator.COLOR, 0.5), 2.0, true)
		draw_arc(Vector2.ZERO, 16.0, -PI / 2.0, -PI / 2.0 + TAU * p, 32, Replicator.LIGHT, 3.0, true)
