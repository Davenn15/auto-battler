class_name CelerityConversionStatus
extends Status
## The unit can't gain Celerity: anything that would raise it above its base adds that
## much to both Might and Insight instead. Celerity can still be lowered.


func modify_final_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	var base: float = unit.base_stats[Stats.Stat.CELERITY]
	match stat:
		Stats.Stat.CELERITY:
			return minf(value, base)
		Stats.Stat.MIGHT, Stats.Stat.INSIGHT:
			var gained := unit.get_stat_before_final(Stats.Stat.CELERITY) - base
			return value + maxf(gained, 0.0)
	return value
