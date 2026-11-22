class_name Grit
extends Status
## The Grit keyword (Stats.Stat.GRIT, always with an amount): a unit with X Grit takes X%
## of each hit (at most 100%) spread evenly over the next Stats.GRIT_DURATION seconds
## instead of all at once. Grit over 100 turns into max health (Stats.GRIT_HEALTH per
## point). Sources stack: Bescard's passive, the Grit Ascension, and anything later.
##
## Every unit carries one of these from the start of combat; it does nothing without Grit.
## It's attached before anything else, so it sits ahead of every shield and catches hits
## before a shield can absorb them. Wards have already been applied by the time a hit is
## held; shields and other effects apply as the held damage is dealt.

const HELD_COLOR := Color(0.75, 0.2, 0.2)   # dark red, so held hits read differently
const COLOR := Color(0.85, 0.55, 0.3)       # the keyword: a rusty ochre
const CHECK_TIME := 0.25                    # how often excess Grit's health is updated

var _hits: Array = []   # each: {"remaining": damage left to deal, "rate": damage per second}
var _releasing := false   # true while dealing held damage, so it isn't caught again
var _granted := 0.0       # max health given by Grit over 100
var _check := 0.0


## Share of each hit held back right now (0 to 1).
static func share(unit: BattleUnit) -> float:
	return clampf(unit.get_stat(Stats.Stat.GRIT) / 100.0, 0.0, 1.0)


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
	if _releasing or damage <= 0.0:
		return damage
	var held := damage * share(unit)
	if held <= 0.0:
		return damage
	unit._spawn_damage_number(held, unit.incoming_color)
	_hits.append({"remaining": held, "rate": held / Stats.GRIT_DURATION})
	return damage - held

## Reduces damage, so Pure Damage skips it (see Status.reduces_damage).
func reduces_damage(_unit: BattleUnit) -> bool:
	return true


func tick(unit: BattleUnit, delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_TIME
		_update_health(unit)
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


## Grit over 100 gives max health. It follows the stat as it changes: gaining heals by the
## same amount, losing only trims health to the new max.
func _update_health(unit: BattleUnit) -> void:
	var want := maxf(unit.get_stat(Stats.Stat.GRIT) - 100.0, 0.0) * Stats.GRIT_HEALTH
	if is_equal_approx(want, _granted):
		return
	_resize(unit, want - _granted)
	_granted = want


func on_removed(unit: BattleUnit) -> void:
	if _granted != 0.0:
		_resize(unit, -_granted)   # each combat starts afresh
		_granted = 0.0


func _resize(unit: BattleUnit, change: float) -> void:
	unit.max_health = maxf(unit.max_health + change, 1.0)
	unit.health = minf(unit.health + maxf(change, 0.0), unit.max_health)
	if unit.health_bar != null:
		unit.health_bar.max_value = unit.max_health
	unit._update_health_bar()
	unit._update_health_ticks()


## Damage still waiting to be dealt.
func get_pending() -> float:
	var total := 0.0
	for hit in _hits:
		total += hit["remaining"]
	return total


## Lets the health bar show the held damage as health about to be lost.
func get_pending_damage(_unit: BattleUnit) -> float:
	return get_pending()


## Drops all held damage without dealing it (Bescard A1).
func clear() -> void:
	_hits.clear()


## The unit's Grit status (every unit has one in combat), or null.
static func of(unit: BattleUnit) -> Grit:
	for status in unit.statuses:
		if status is Grit:
			return status
	return null
