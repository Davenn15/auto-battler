class_name ReplicantOnGambitEffect
extends Passive
## An Ascension effect (Spawn Protocol): whenever the unit casts its Gambit, REPLK4NTs
## appear in free cells beside it, made the way REPL\K8R's seeds make them: the REPLK4NT's
## own body plus a share of the unit's max health and of its attributes and wards.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## The REPLK4NT: its own look, stats and Gambit.
@export var profile: UnitData
## REPLK4NTs per Gambit cast.
@export var count: int = 1
## Share of the unit's max health the REPLK4NT adds to its own, and of its attributes and wards.
@export_range(0.0, 1.0, 0.05) var health_share: float = 0.2
@export_range(0.0, 1.0, 0.05) var stat_share: float = 0.2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SpawnStatus.new(self))


## Summons the REPLK4NTs beside `unit`, at full health.
func spawn(unit: BattleUnit) -> void:
	if profile == null or not is_instance_valid(unit) or not unit.alive or not unit.is_inside_tree():
		return
	var parent := unit.get_parent()
	for cell in Replicator.free_cells_near(unit.grid, unit.cell, count):
		var replicant := UNIT_SCENE.instantiate() as BattleUnit
		replicant.data = profile
		replicant.team = unit.team
		replicant.auto_place = false
		replicant.is_summon = true
		replicant.summon_keeps_gambit = true
		replicant._summoner_id = unit.get_credit_id()
		replicant._summon_max_health = profile.max_health + unit.max_health * health_share
		for stat in Stats.Stat.values():
			var value := profile.get_base_stat(stat)
			if stat in SeedGambit.SHARED_STATS:
				value += unit.get_stat(stat) * stat_share
			replicant._summon_stats[stat] = value
		parent.add_child(replicant)
		replicant.place_at(cell)
		replicant.get_tree().call_group("battle_manager", "add_summon", replicant)
		if is_instance_valid(replicant) and not replicant.is_queued_for_deletion():
			KeepsakeVfx.missile_blast(parent, replicant.global_position, 34.0, Replicator.COLOR)


## Listens for the unit's Gambit casts.
class SpawnStatus extends Status:
	var effect: ReplicantOnGambitEffect
	var _unit   # untyped: may be freed

	func _init(p_effect: ReplicantOnGambitEffect) -> void:
		effect = p_effect

	func on_applied(unit: BattleUnit) -> void:
		_unit = unit
		if not unit.gambit_cast.is_connected(_on_cast):
			unit.gambit_cast.connect(_on_cast)

	func on_removed(unit: BattleUnit) -> void:
		if is_instance_valid(unit) and unit.gambit_cast.is_connected(_on_cast):
			unit.gambit_cast.disconnect(_on_cast)

	func _on_cast(unit: BattleUnit) -> void:
		effect.spawn(unit)
