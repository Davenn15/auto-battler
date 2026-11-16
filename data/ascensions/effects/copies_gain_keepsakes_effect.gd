class_name CopiesGainKeepsakesEffect
extends Passive
## An Ascension effect (Perfect Reflection): the unit's copies of itself (summons made from
## the same unit, like Bremes' Mirror Image) gain its Keepsakes, stats and effects, when
## they appear.


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(CopyKeepsakesStatus.new())


class CopyKeepsakesStatus extends Status:
	func on_summoned(unit: BattleUnit, summon: BattleUnit) -> void:
		if summon.data != unit.data:
			return   # only copies of itself
		for keepsake in unit.keepsakes:
			if summon.keepsakes.size() >= BattleUnit.MAX_KEEPSAKES:
				break
			summon.swap_keepsake_in_combat(keepsake)
