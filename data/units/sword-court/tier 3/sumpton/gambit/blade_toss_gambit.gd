class_name BladeTossGambit
extends Gambit
## Reaches into the bag and tosses blades one at a time to random nearby allies. Each
## blade gives its ally an attribute and the matching ward for the rest of combat:
## Might and Might Ward, Insight and Insight Ward, or Celerity and Celerity Ward.

## Each kind of blade: [attribute, ward]. In the same order as Stats.DamageType, so a
## blade's index is also its damage type, which picks its color.
const BLADE_KINDS := [
	[Stats.Stat.MIGHT, Stats.Stat.MIGHT_WARD],
	[Stats.Stat.INSIGHT, Stats.Stat.INSIGHT_WARD],
	[Stats.Stat.CELERITY, Stats.Stat.CELERITY_WARD],
]

## Blades tossed per cast.
@export var blades: int = 4
## Seconds between tosses. The caster can't move or attack while tossing.
@export var toss_interval: float = 0.3
## How far away an ally can be to catch a blade, in hex cells.
@export var range_cells: int = 3
@export var attribute_bonus: float = 12.0
@export var ward_bonus: float = 8.0
## Seconds a blade spends in the air.
@export var flight_time: float = 0.35
## Shield each blade gives the ally that catches it. 0 = none.
@export var blade_shield: float = 0.0
@export var blade_shield_duration: float = 4.0
## Charge each blade gives the ally that catches it. 0 = none.
@export var blade_charge: float = 0.0

func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var count := blades + _take_bonus_blades(caster)
	caster.lock_for(count * toss_interval)
	for i in count:
		# The caster may have died, or the battle ended, between tosses.
		if not _alive(caster) or not caster.active:
			return
		_toss(caster, _random_ally(caster), CombatRng.randi_range(0, BLADE_KINDS.size() - 1))
		await caster.get_tree().create_timer(toss_interval, true, true).timeout

## Extra blades banked by allies' wracks (Sumpton's A2), used up by this cast. 0 without A2.
func _take_bonus_blades(caster: BattleUnit) -> int:
	for status in caster.statuses:
		if status is WrackTallyStatus:
			return status.take()
	return 0

## A random living ally within range, other than the caster. The caster itself if
## nobody is near.
func _random_ally(caster: BattleUnit) -> BattleUnit:
	var options: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive or unit.team != caster.team:
			continue
		if caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			options.append(unit)
	return caster if options.is_empty() else CombatRng.pick(options)


## Sends a spinning blade of kind `kind` (an index into BLADE_KINDS) flying to `ally`.
## The buff is given when it lands.
func _toss(caster: BattleUnit, ally: BattleUnit, kind: int) -> void:
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([Vector2(-6, -2), Vector2(8, 0), Vector2(-6, 2)])
	blade.color = Stats.damage_color(kind)
	blade.z_index = 10
	caster.get_tree().current_scene.add_child(blade)
	blade.global_position = caster.global_position
	blade.set_meta("caster_id", caster.get_instance_id())
	var tween := blade.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(blade, "global_position", ally.global_position, flight_time)
	tween.parallel().tween_property(blade, "rotation", TAU * 2.0, flight_time)   # two spins
	tween.tween_callback(_land.bind(blade, ally, kind))


## Untyped `ally`: it may have died and been freed while the blade was in the air.
func _land(blade: Polygon2D, ally, kind: int) -> void:
	blade.queue_free()
	if not _alive(ally):
		return
	var stats: Array = BLADE_KINDS[kind]
	ally.add_status(BladeBuffStatus.new(stats[0], stats[1], attribute_bonus, ward_bonus))
	ally.show_float_text("+" + Stats.STAT_NAMES[stats[0]], Stats.damage_color(kind))
	if blade_shield > 0.0:
		ally.add_shield(blade_shield, blade_shield_duration, blade.get_meta("caster_id"))
	if blade_charge > 0.0:
		ally.gain_charge(blade_charge)


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
