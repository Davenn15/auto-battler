class_name DelayedDamageStatus
extends Status
## Holds back damage the unit takes and deals each hit evenly over `duration` seconds.
## Wards have already been applied by the time a hit is held. Shields and other effects
## apply as the damage is dealt. Pauses outside combat; the next battle's status reset
## clears anything left over.
## Attached at battle start, so it sits ahead of any shield in the unit's list and
## catches hits before a shield can absorb them.

const DELAYED_COLOR := Color(0.75, 0.2, 0.2)   # dark red, so held hits read differently

var duration: float
var _hits: Array = []   # each: {"remaining": damage left to deal, "rate": damage per second}
var _releasing: bool = false   # true while dealing held damage, so it isn't caught again


func _init(p_duration: float) -> void:
	duration = maxf(p_duration, 0.01)


func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
	if _releasing or damage <= 0.0:
		return damage
	unit._spawn_damage_number(damage, unit.incoming_color)
	_hits.append({"remaining": damage, "rate": damage / duration})
	return 0.0


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active or _hits.is_empty():
		return
	var amount := 0.0
	for hit in _hits:
		var step := minf(hit["rate"] * delta, hit["remaining"])
		hit["remaining"] -= step
		amount += step
	_hits = _hits.filter(func(h): return h["remaining"] > 0.0)
	_releasing = true
	unit.take_warded_damage(amount)
	_releasing = false


## Damage still waiting to be dealt.
func get_pending() -> float:
	var total := 0.0
	for hit in _hits:
		total += hit["remaining"]
	return total
