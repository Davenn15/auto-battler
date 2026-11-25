class_name TauntGambit
extends Gambit
## Taunts every enemy within range: they're forced to attack the caster for a while. For
## each enemy taunted, the caster gains wards for a while.

## How close enemies must be to be taunted, in hex cells.
@export var range_cells: int = 2
## Seconds the taunt lasts.
@export var taunt_time: float = 4.0
## Added to all three wards per enemy taunted.
@export var ward_per_taunt: float = 15.0
## Seconds the ward bonus lasts.
@export var ward_time: float = 4.0
## Lordred B: the first time each combat the caster is still alive when the ward bonus
## ends, it gains Glory.
@export var glory_on_survive: bool = false


func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_range(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var taunted := 0
	# An item can let control effects wrack: one roll lengthens every taunt.
	var duration := taunt_time * caster.wrack_effect_multiplier(Stats.EffectKind.CONTROL)
	for enemy in _enemies_in_range(caster):
		if enemy.is_cc_immune():
			continue
		for old in enemy.statuses.duplicate():
			if old is TauntedStatus:
				enemy.remove_status(old)   # the newest taunt wins
		enemy.add_status(TauntedStatus.new(caster, duration))
		taunted += 1
	if taunted == 0:
		return
	for ward in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
		caster.add_status(TimedStatStatus.new(ward, ward_per_taunt * taunted, ward_time))
	caster.show_float_text("Taunt ×%d" % taunted, Color(0.85, 0.15, 0.15))
	KeepsakeVfx.taunt_ring(caster, ward_time)   # lasts as long as the Ward bonus
	if glory_on_survive and not caster.statuses.any(func(s): return s is TauntGloryStatus):
		caster.add_status(TauntGloryStatus.new(ward_time))


## Counts down the first Taunt's Ward bonus; if the unit is still alive at the end (statuses
## stop ticking when it dies), it gains Glory. Stays on afterwards, so it's once per combat.
class TauntGloryStatus extends Status:
	var time_left: float
	var done := false

	func _init(p_time: float) -> void:
		time_left = p_time

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, delta: float) -> void:
		if done:
			return
		time_left -= delta
		if time_left <= 0.0:
			done = true
			if unit.alive:
				unit.gain_glory()


func _enemies_in_range(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and caster._is_valid_target(unit) \
				and caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			result.append(unit)
	return result
