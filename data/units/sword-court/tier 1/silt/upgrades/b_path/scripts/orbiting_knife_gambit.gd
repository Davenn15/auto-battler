class_name OrbitingKnifeGambit
extends Gambit
## Sends one of the caster's knives to orbit its fastest allies. While it orbits, each of
## their attacks that lands is followed by a knife strike, credited to the caster.

@export var duration: float = 6.0
@export var knife_damage: float = 20.0
## Extra knife damage per point of the caster's Might.
@export var might_scaling: float = 0.3
## How many allies get a knife, highest Celerity first.
@export var ally_count: int = 1
## Insight Ward the knife grants while it orbits. 0 = none.
@export var insight_ward_bonus: float = 0.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Locked in at cast time, so the knives keep working if the caster dies.
	var damage := Stats.scaled(knife_damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var wrack_multiplier := 1.0 + caster.get_stat(Stats.Stat.WRACK_DAMAGE)
	for ally in _pick_allies(caster):
		# Recasting on someone replaces their knife instead of stacking a second one.
		for status in ally.statuses.duplicate():
			if status is OrbitingKnifeStatus:
				ally.remove_status(status)
		ally.add_status(OrbitingKnifeStatus.new(caster, damage, wrack_multiplier, duration, insight_ward_bonus))


## The `ally_count` allies with the highest Celerity. Falls back to the caster if alone.
func _pick_allies(caster: BattleUnit) -> Array[BattleUnit]:
	var allies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team == caster.team and unit != caster:
			allies.append(unit)
	if allies.is_empty():
		allies.append(caster)
	allies.sort_custom(func(a, b): return a.get_stat(Stats.Stat.CELERITY) > b.get_stat(Stats.Stat.CELERITY))
	return allies.slice(0, ally_count)
