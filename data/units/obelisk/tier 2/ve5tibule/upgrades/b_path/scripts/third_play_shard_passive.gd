class_name ThirdPlayShardPassive
extends Passive
## Vestibule B2: the Play Count-th time each combat he plays his Gambit, his player gains a
## random Shard in their Keepsake inventory after the combat (real combats only, see
## ArmySpawner.earn_shard).

@export var play_count: int = 3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ThirdPlayStatus.new(self))


class ThirdPlayStatus extends Status:
	var passive: ThirdPlayShardPassive
	var _plays := 0

	func _init(p_passive: ThirdPlayShardPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_played(unit: BattleUnit) -> void:
		_plays += 1
		if _plays != passive.play_count:
			return
		var kind: Shard.Kind = CombatRng.pick(Shard.Kind.values())
		ArmySpawner.earn_shard(unit.team, kind)
		KeepsakeForge.created(unit, 1)
		unit.show_float_text("+%s Shard" % Shard.NAMES[kind], StunBoltGambit.COLOR)
