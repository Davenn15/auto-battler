class_name VacuumChannel
extends Node2D
## A running Vacuum (see VacuumGambit): drains its targets every physics step until time
## runs out or Recycloid dies. Draws streams of motes flowing from each target into him.

var caster: BattleUnit
var targets: Array = []   # untyped: targets may be freed
var time_left: float
var damage_per_second: float
var damage_type: int
var charge_on_kill: float
var execute_threshold: float
var _living := {}          # ids of targets not yet seen dead, so each death counts once
var _ids: Array[int] = []  # each target's id, recorded while it was alive
var _time := 0.0



## Sets who it drains, remembering each one so their deaths can be counted later.
func set_targets(list: Array) -> void:
	targets = list.duplicate()
	for target in targets:
		_ids.append(target.get_instance_id())
		_living[target.get_instance_id()] = true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree() or time_left <= 0.0:
		_end()
		return
	time_left -= delta
	var credit := caster.get_credit_id()
	_count_deaths()
	for target in targets.duplicate():
		if not is_instance_valid(target) or not target.alive:
			continue
		var dealt: float = target.take_damage(target.max_health * damage_per_second * delta, 0, damage_type, false, caster, false)
		get_tree().call_group("damage_tracker", "record_damage", credit, dealt)
		target.add_running_damage("vacuum_%d" % get_instance_id(), dealt, Stats.damage_color(damage_type))
		if target.alive and execute_threshold > 0.0 and target.health / target.max_health < execute_threshold:
			target.show_float_text("Executed", VACUUM_COLOR)
			target.kill()
	_count_deaths()
	if targets.all(func(t): return not is_instance_valid(t) or not t.alive):
		_end()


## Any target that has died since last time, whoever killed it, counts once for Draining.
func _count_deaths() -> void:
	for i in targets.size():
		var target = targets[i]
		if not is_instance_valid(target) or not target.alive:
			var id: int = _ids[i]
			if _living.erase(id):
				_on_target_died()


## Draining (A): a burst of Charge, straight into the bar (he's locked while channelling, which
## would otherwise block it).
func _on_target_died() -> void:
	if charge_on_kill > 0.0 and is_instance_valid(caster) and caster.alive:
		caster.charge = minf(caster.charge + charge_on_kill, caster.max_charge)
		caster._update_charge_bar()


func _end() -> void:
	if is_instance_valid(caster) and caster.alive:
		caster._locked_time = 0.0   # free to act again (the channel may end early)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(caster):
		return
	var to := to_local(caster.global_position)
	for target in targets:
		if not is_instance_valid(target) or not target.alive:
			continue
		var from := to_local(target.global_position)
		draw_line(from, to, Color(VACUUM_COLOR, 0.18), 6.0, true)
		for i in 7:
			var t := fmod(_time * 1.6 + i / 7.0, 1.0)   # motes travel from the target to him
			var pos := from.lerp(to, t) + (to - from).orthogonal().normalized() * sin(t * TAU * 2.0 + i) * 4.0
			draw_circle(pos, 3.5 * (1.0 - t * 0.5), Color(VACUUM_COLOR, 0.9 * (1.0 - t * 0.6)))


const VACUUM_COLOR := Color(0.45, 1.0, 0.45)
