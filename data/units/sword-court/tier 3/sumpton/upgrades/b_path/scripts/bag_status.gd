class_name BagStatus
extends Status
## Makes a unit act as Sumpton's blade bag: it never moves or attacks on its own, and
## fires a blade at a random nearby enemy every few seconds. Everything it needs is
## copied in, so it keeps going if Sumpton dies.

const BLADE_COLOR := Color(0.85, 0.9, 1.0)

var interval: float
var range_cells: int
var damage: float
var _timer: float


func _init(p_interval: float, p_range_cells: int, p_damage: float, p_first_delay: float) -> void:
	interval = p_interval
	range_cells = p_range_cells
	damage = p_damage
	_timer = p_first_delay


func tick(unit: BattleUnit, delta: float) -> void:
	unit.lock_for(0.1)   # a bag stays put; this keeps it from walking or attacking
	if not unit.active:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer += interval
	var target := _random_enemy(unit)
	if target == null:
		return
	var blade := Projectile.new()
	blade.setup(unit, target, damage, BLADE_COLOR, 0, Stats.DamageType.MIGHT)
	unit.get_tree().current_scene.add_child(blade)
	blade.global_position = unit.global_position


func _random_enemy(unit: BattleUnit) -> BattleUnit:
	var options: Array[BattleUnit] = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and unit._is_valid_target(other) \
				and unit.grid.get_distance(unit.cell, other.cell) <= range_cells:
			options.append(other)
	return null if options.is_empty() else options.pick_random()
