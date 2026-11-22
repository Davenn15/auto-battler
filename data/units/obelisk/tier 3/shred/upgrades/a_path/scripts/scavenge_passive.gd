class_name ShredScavengePassive
extends Passive
## SHRED A2: whenever SHRED kills an enemy with direct damage (attacks, Gambit hits), there's
## a Chance its player gains one of that enemy's Shards after the combat: picked at random
## from the Shards making up its Keepsakes (two per combined Keepsake, one per Shard).
## Nothing if it has no Keepsakes. Only real combats pay out (see ArmySpawner.earn_shard).

@export_range(0.0, 1.0, 0.05) var chance: float = 0.35


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ScavengeStatus.new(self))


class ScavengeStatus extends Status:
	var passive: ShredScavengePassive
	var _rolled := {}   # enemies already rolled for, so one kill never rolls twice

	func _init(p_passive: ShredScavengePassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_direct_damage_dealt(unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
		if not is_instance_valid(target) or target.alive or target.team == unit.team:
			return
		var id := target.get_instance_id()
		if _rolled.has(id):
			return
		_rolled[id] = true
		var kinds: Array = []
		for keepsake in target.keepsakes:
			if keepsake == null:
				continue
			kinds.append(keepsake.first_shard)
			if not keepsake.is_shard:
				kinds.append(keepsake.second_shard)
		if kinds.is_empty() or CombatRng.randf() >= passive.chance:
			return
		var kind: Shard.Kind = CombatRng.pick(kinds)
		ArmySpawner.earn_shard(unit.team, kind)
		unit.show_float_text("+%s Shard" % Shard.NAMES[kind], ShredFx.LIGHT)
