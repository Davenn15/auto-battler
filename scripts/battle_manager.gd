class_name BattleManager
extends Node
signal battle_ended(winning_team: int)   # -1 if no units remain

enum Phase { PREP, COMBAT, RESULT }
var phase: Phase = Phase.PREP

@export var auto_start: bool = true   # turn off once you have a Fight button
@export var damage_tracker: DamageTracker

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

## Brings a unit created mid-battle into the fight: tracks its death and its damage.
func add_summon(unit: BattleUnit) -> void:
	if phase != Phase.COMBAT:
		unit.queue_free()
		return
	unit.died.connect(_on_unit_died)
	unit.start_combat()

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
