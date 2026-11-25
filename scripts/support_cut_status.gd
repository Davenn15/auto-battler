class_name SupportCutStatus
extends Status
## A debuff: the unit receives Cut less healing and shielding for a while (Blizzard's and
## Opportunist's Empowerments). One per Key: applying it again refreshes it.

var key: String
var cut: float
var time_left: float


func _init(p_key: String, p_cut: float, p_duration: float) -> void:
	key = p_key
	cut = p_cut
	time_left = p_duration


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


## Gives `target` the debuff (or refreshes it, keeping the bigger cut).
static func apply(target: BattleUnit, p_key: String, p_cut: float, duration: float) -> void:
	if not is_instance_valid(target) or not target.alive or p_cut <= 0.0:
		return
	for status in target.statuses:
		if status is SupportCutStatus and status.key == p_key:
			status.cut = maxf(status.cut, p_cut)
			status.time_left = maxf(status.time_left, duration * target.debuff_multiplier())
			return
	target.add_status(SupportCutStatus.new(p_key, p_cut, duration * target.debuff_multiplier()))


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


func modify_healing_received(_unit: BattleUnit, amount: float) -> float:
	return amount * (1.0 - cut)


func modify_shield_received(_unit: BattleUnit, amount: float) -> float:
	return amount * (1.0 - cut)
