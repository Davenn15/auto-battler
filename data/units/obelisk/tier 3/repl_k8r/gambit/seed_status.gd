class_name SeedStatus
extends Status
## A replication seed growing in an ally. Hatches into a REPLK4NT (see SeedGambit) after its
## gestation, or at once if the ally dies. With REPL\K8R's A path it also raises its host's
## health regen while it's there.

var gambit: SeedGambit
var owner: Dictionary   # SeedGambit.snapshot of the REPL\K8R that planted it
var _time := 0.0
var _hatched := false
var _mark: SeedMark


static func has_seed(unit: BattleUnit) -> bool:
	for status in unit.statuses:
		if status is SeedStatus:
			return true
	return false


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func on_applied(unit: BattleUnit) -> void:
	unit.died.connect(_on_host_died)
	if KeepsakeVfx.enabled():
		_mark = SeedMark.new()
		_mark.source = self
		_mark.z_index = 13
		unit.add_child(_mark)
		_mark.position = Vector2(20, 14)   # beside the host, clear of icons over its head


func on_removed(unit: BattleUnit) -> void:
	if unit.died.is_connected(_on_host_died):
		unit.died.disconnect(_on_host_died)
	if is_instance_valid(_mark):
		_mark.queue_free()


func progress() -> float:
	return clampf(_time / gambit.gestation, 0.0, 1.0) if gambit.gestation > 0.0 else 1.0


## A: the host regenerates faster while it carries the seed.
func modify_health_regen(_unit: BattleUnit, regen: float) -> float:
	return regen + gambit.seed_regen


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active:
		unit.remove_status(self)
		return
	_time += delta
	if _time >= gambit.gestation:
		_hatch(unit)
		unit.remove_status(self)


func _on_host_died(unit: BattleUnit) -> void:
	_hatch(unit)


func _hatch(host: BattleUnit) -> void:
	if _hatched:
		return
	_hatched = true
	gambit.hatch(host, owner, progress())


## The seed drawn on its host: a green seed that swells, ringed by how far along it is.
class SeedMark extends Node2D:
	var source: SeedStatus
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if source == null:
			return
		var p := source.progress()
		var pulse := 1.0 + 0.12 * sin(_time * (4.0 + 8.0 * p))
		var size := (6.0 + 5.0 * p) * pulse
		draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.45))   # dark backing so it reads
		draw_circle(Vector2.ZERO, size + 3.0, Color(Replicator.COLOR, 0.4))
		draw_circle(Vector2.ZERO, size, Replicator.COLOR)
		draw_circle(Vector2(-size * 0.3, -size * 0.3), size * 0.35, Color(Replicator.LIGHT, 0.8))
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(Replicator.COLOR, 0.5), 2.0, true)
		draw_arc(Vector2.ZERO, 16.0, -PI / 2.0, -PI / 2.0 + TAU * p, 32, Replicator.LIGHT, 3.0, true)
