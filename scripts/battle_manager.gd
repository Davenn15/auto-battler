class_name BattleManager
extends Node
signal battle_ended(winning_team: int)   # -1 if no units remain

enum Phase { PREP, COMBAT, RESULT }
var phase: Phase = Phase.PREP

@export var auto_start: bool = true   # turn off once you have a Fight button
@export var damage_tracker: DamageTracker

signal overtime_started

@export_group("Overtime")
## Seconds into combat before overtime starts. 0 = never.
@export var overtime_after: float = 40.0
## Celerity every unit gains when overtime starts.
@export var overtime_celerity_bonus: float = 30.0
## Extra Celerity per second of overtime, on top of the bonus. 0 = a flat bonus.
@export var overtime_celerity_per_second: float = 5
## Healing and shields received are multiplied by these in overtime (0.5 = halved).
@export_range(0.0, 1.0, 0.05) var overtime_healing_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.05) var overtime_shield_multiplier: float = 0.5

var combat_time: float = 0.0
var in_overtime: bool = false
## Seeds every roll in the fight (see CombatRng). Two computers with the same armies and
## the same seed play the same fight. Negative = pick one at random.
var combat_seed: int = -1


func _ready() -> void:
	add_to_group("battle_manager")
	if auto_start:
		# Wait one physics frame so all units are ready and the navmesh has synced.
		await get_tree().physics_frame
		start_battle()


func start_battle() -> void:
	if phase != Phase.PREP:
		return
	phase = Phase.COMBAT
	CombatRng.start(combat_seed if combat_seed >= 0 else randi())
	combat_time = 0.0
	in_overtime = false
	if damage_tracker != null:
		damage_tracker.reset()
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null:
			continue
		unit.died.connect(_on_unit_died)
		if damage_tracker != null:
			damage_tracker.register(unit)
		unit.start_combat()
	_check_battle_end()   # handles a side starting with zero units

func _physics_process(delta: float) -> void:
	if phase != Phase.COMBAT:
		return
	combat_time += delta
	if not in_overtime and overtime_after > 0.0 and combat_time >= overtime_after:
		_start_overtime()


func _start_overtime() -> void:
	in_overtime = true
	for node in get_tree().get_nodes_in_group("units"):
		_apply_overtime(node as BattleUnit)
	overtime_started.emit()


func _apply_overtime(unit: BattleUnit) -> void:
	if unit != null:
		unit.add_status(OvertimeStatus.new(overtime_celerity_bonus, overtime_celerity_per_second,
				overtime_healing_multiplier, overtime_shield_multiplier))

## Brings a unit created mid-battle into the fight: tracks its death and its damage.
func add_summon(unit: BattleUnit) -> void:
	if phase != Phase.COMBAT:
		unit.queue_free()
		return
	unit.died.connect(_on_unit_died)
	unit.start_combat()
	if in_overtime:
		_apply_overtime(unit)   # after start_combat, which clears statuses

func _on_unit_died(unit: BattleUnit) -> void:
	print("%s died" % unit.name)
	_check_battle_end()


func _check_battle_end() -> void:
	if phase != Phase.COMBAT:
		return
	# Units leave the "units" group before emitting `died`, so this count is current.
	var teams_alive := {}
	for node in get_tree().get_nodes_in_group("units"):
		teams_alive[(node as BattleUnit).team] = true
	if teams_alive.size() > 1:
		return

	phase = Phase.RESULT
	for node in get_tree().get_nodes_in_group("units"):
		(node as BattleUnit).stop_combat()
	var winner: int = teams_alive.keys()[0] if teams_alive.size() == 1 else -1
	battle_ended.emit(winner)
