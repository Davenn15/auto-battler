class_name ReplicantOnGambitEffect
extends Passive
## An Ascension effect (Spawn Protocol): every time the unit has spent Charge Threshold
## Charge on its Gambit (the whole bar, each time it casts), Count Replicants appear in free
## cells beside it when that Gambit plays. Charge spent past a threshold carries over toward the next one, for the
## rest of the combat. They're made the way Replicator's seeds make them: the Replicant's own
## body plus a share of the unit's max health and of its attributes and wards.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## The Replicant: its own look, stats and Gambit.
@export var profile: UnitData
## Replicants each time the threshold is reached.
@export var count: int = 1
## Charge the unit must spend for each spawn.
@export var charge_threshold: float = 100.0
## Share of the unit's max health the Replicant adds to its own, and of its attributes and wards.
@export_range(0.0, 1.0, 0.05) var health_share: float = 0.2
@export_range(0.0, 1.0, 0.05) var stat_share: float = 0.2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SpawnStatus.new(self))


## Summons the Replicants beside `unit`, at full health.
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
			if unit.gambit is SeedGambit:   # a Replicator: its Replicant upgrades apply to these too
				var seeds := unit.gambit as SeedGambit
				seeds.buff_replicant(replicant, seeds.snapshot(unit))
			KeepsakeVfx.missile_blast(parent, replicant.global_position, 34.0, Replicator.COLOR)


## Counts the Charge the unit spends on its Gambit (all of it, at each cast).
class SpawnStatus extends Status:
	var effect: ReplicantOnGambitEffect
	var spent := 0.0   # Charge spent toward the next spawn

	func _init(p_effect: ReplicantOnGambitEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	var _due := 0   # spawns earned at the cast, waiting for the Gambit to play

	## The Charge is counted when it's spent (the cast)...
	func on_gambit(unit: BattleUnit) -> void:
		spent += unit.max_charge
		var threshold := maxf(effect.charge_threshold, 1.0)
		while spent >= threshold:
			spent -= threshold
			_due += 1

	## ...and the Replicants it earned appear when the Gambit plays.
	func on_gambit_played(unit: BattleUnit) -> void:
		while _due > 0:
			_due -= 1
			effect.spawn(unit)
