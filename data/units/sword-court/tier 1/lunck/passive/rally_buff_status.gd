class_name RallyBuffStatus
extends Status
## The Celerity an ally receives from a Rally aura. Attached and removed by the source's
## RallyAuraStatus as the ally enters and leaves range, and removes itself if the source dies.

var source_id: int      # instance id of the unit providing the aura
var celerity: float
var insight


func _init(p_source_id: int, p_celerity: float, p_insight: float = 0.0) -> void:
	source_id = p_source_id
	celerity = p_celerity
	insight = p_insight


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.CELERITY:
		return value + celerity
	if stat == Stats.Stat.INSIGHT:
		return value + insight
	return value


func tick(unit: BattleUnit, _delta: float) -> void:
	var source := instance_from_id(source_id) as BattleUnit
	if source == null or not source.alive:
		unit.remove_status(self)
