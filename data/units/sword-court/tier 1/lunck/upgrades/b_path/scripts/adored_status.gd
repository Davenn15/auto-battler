class_name AdoredStatus
extends Status
## Extra wrack chance for a while, from Lunck's Adoring gambit. With charge_on_kill
## above 0, each kill this unit makes gives the source that much charge.

var source_id: int
var wrack_chance: float
var charge_on_kill: float
var time_left: float


func _init(p_source_id: int, p_wrack_chance: float, p_charge_on_kill: float, p_duration: float) -> void:
	source_id = p_source_id
	wrack_chance = p_wrack_chance
	charge_on_kill = p_charge_on_kill
	time_left = p_duration


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	return value + wrack_chance if stat == Stats.Stat.WRACK_CHANCE else value


func on_kill(_unit: BattleUnit, _victim: BattleUnit) -> void:
	if charge_on_kill <= 0.0:
		return
	var source := instance_from_id(source_id) as BattleUnit
	if source != null and source.alive:
		source.gain_charge(charge_on_kill)


## A buff, not a casting state, so it never blocks charge (matters for B2).
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false
