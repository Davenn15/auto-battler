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

const DECAY_COLOR := Color(0.6, 0.45, 0.3)   # the bag fraying

## Once the summoner dies, the bag loses this share of its max health per second...
var decay_start: float
## ...and the rate climbs by this share every second after that.
var decay_ramp: float
var _orphaned_for: float = -1.0   # seconds since the summoner died; -1 while it lives

func _init(p_interval: float, p_range_cells: int, p_damage: float, p_first_delay: float,
		p_decay_start: float, p_decay_ramp: float) -> void:
	interval = p_interval
	range_cells = p_range_cells
	damage = p_damage
	_timer = p_first_delay
	decay_start = p_decay_start
	decay_ramp = p_decay_ramp


func tick(unit: BattleUnit, delta: float) -> void:
	unit.lock_for(0.1)   # a bag stays put; this keeps it from walking or attacking
	if not unit.active:
		return
	_decay(unit, delta)
	if not unit.alive:
		return   # the decay finished it off
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

## Once the summoner is dead, the bag starts falling apart: damage over time that grows
## the longer it's been on its own.
func _decay(unit: BattleUnit, delta: float) -> void:
	if _orphaned_for < 0.0:
		var owner := instance_from_id(unit.get_credit_id()) as BattleUnit
		if owner != null and owner.alive:
			return
		_orphaned_for = 0.0
		unit.show_float_text("Unraveling", DECAY_COLOR)
	_orphaned_for += delta
	var rate := decay_start + decay_ramp * _orphaned_for   # share of max health per second
	unit.add_running_damage("self_burn", unit.take_warded_damage(unit.max_health * rate * delta), DECAY_COLOR)

func _random_enemy(unit: BattleUnit) -> BattleUnit:
	var options: Array[BattleUnit] = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and unit._is_valid_target(other) \
				and unit.grid.get_distance(unit.cell, other.cell) <= range_cells:
			options.append(other)
	return null if options.is_empty() else CombatRng.pick(options)
