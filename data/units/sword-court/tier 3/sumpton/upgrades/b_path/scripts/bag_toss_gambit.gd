class_name BagTossGambit
extends Gambit
## Throws the blade bag to the free cell with the most enemies around it. On landing it
## hurts every enemy next to it, then sits there firing blades at random nearby enemies
## until it's destroyed. Casting again while the bag is out makes it leap to a new spot
## and land again.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## How the bag looks: its name and sprite. Its numbers come from Sumpton.
@export var bag_profile: UnitData
## How far from Sumpton the bag can land, in hex cells.
@export var throw_range_cells: int = 5
## Seconds the bag spends in the air.
@export var flight_time: float = 0.5
## Damage to each enemy within Landing Radius = Landing Damage + Landing Might Scaling x Might.
@export var landing_damage: float = 120.0
@export var landing_might_scaling: float = 0.6
@export var landing_radius_cells: int = 1
## Seconds landing stuns the enemies it damages. 0 = none.
@export var landing_stun: float = 0.0
## The bag's max health as a multiple of Sumpton's (1.15 = 15% more than him).
@export var bag_health_fraction: float = 1.15
## The bag's wards as a multiple of Sumpton's base wards.
@export var bag_ward_multiplier: float = 1.15
## Seconds between the bag's blades.
@export var blade_interval: float = 1.2
@export var blade_range_cells: int = 3
## Each blade = Blade Damage + Blade Might Scaling x Sumpton's Might, fixed when thrown.
@export var blade_damage: float = 40.0
@export var blade_might_scaling: float = 0.3
## Each cast heals the bag by this share of its max health (0.25 = 25%). A bag thrown
## after the last one died comes back at this much health instead of full.
@export_range(0.0, 1.0, 0.05) var recast_heal_fraction: float = 0.25
@export_group("After Sumpton dies")
## Share of the bag's max health it loses per second once Sumpton is dead (0.02 = 2%).
@export var decay_start: float = 0.02
## How much that rate climbs every second (0.02 = +2% per second, each second).
@export var decay_ramp: float = 0.02


## Only throws if some landing spot would hit an enemy.
func can_use(caster: BattleUnit) -> bool:
	return _best_cell(caster)["count"] > 0


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var spot := _best_cell(caster)
	if spot["count"] == 0:
		return
	var landing := Stats.scaled(landing_damage, landing_might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	# Items can let the landing's damage and stun wrack. Rolled now, while Sumpton is
	# surely alive, since he may not be when the bag lands.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	landing *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var stun := landing_stun * caster.wrack_effect_multiplier(Stats.EffectKind.CONTROL) if landing_stun > 0.0 else 0.0
	var bag := _find_bag(caster)
	if bag != null:
		bag.heal(bag.max_health * recast_heal_fraction, caster.get_instance_id())
		await bag.dash_to(spot["cell"], flight_time)   # leap to the new spot
	else:
		var first_throw := not _has_thrown(caster)
		bag = _spawn_bag(caster, spot["cell"])
		if first_throw:
			caster.add_status(BagThrownStatus.new())
		else:
			bag.set_health(bag.max_health * recast_heal_fraction)   # the last bag died
		await caster.get_tree().create_timer(flight_time, true, true).timeout
	_land(bag, landing, wrack, stun)

## True once this caster has thrown a bag this battle.
func _has_thrown(caster: BattleUnit) -> bool:
	for status in caster.statuses:
		if status is BagThrownStatus:
			return true
	return false

func _spawn_bag(caster: BattleUnit, cell: Vector2i) -> BattleUnit:
	var bag := UNIT_SCENE.instantiate() as BattleUnit
	bag.setup_as_profile_summon(bag_profile, caster, bag_health_fraction, bag_ward_multiplier)
	caster.get_parent().add_child(bag)   # _ready runs here
	bag.place_at(cell)
	caster.get_tree().call_group("battle_manager", "add_summon", bag)
	# After add_summon: start_combat clears statuses, so these must come later.
	var blade := Stats.scaled(blade_damage, blade_might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	bag.add_status(BagStatus.new(blade_interval, blade_range_cells, blade, flight_time,
			decay_start, decay_ramp))
	# The bag already holds its cell; this only flies it there from Sumpton on screen.
	bag.global_position = caster.global_position
	bag.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(bag, "global_position", caster.grid.cell_to_world(cell), flight_time)
	return bag


## Untyped `bag`: it may have been destroyed while in the air.
func _land(bag, damage_amount: float, wrack: int, stun: float) -> void:
	if not _alive(bag):
		return
	bag.show_float_text("Thud", Color(0.9, 0.75, 0.5))
	for node in bag.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == bag.team:
			continue
		if bag.grid.get_distance(bag.cell, enemy.cell) > landing_radius_cells:
			continue
		var dealt := enemy.take_damage(damage_amount, wrack, Stats.DamageType.MIGHT)
		bag.get_tree().call_group("damage_tracker", "record_damage", bag.get_credit_id(), dealt)
		if stun > 0.0 and dealt > 0.0 and enemy.alive:
			enemy.stun(stun)   # already wracked when thrown


## The free cell within throw range with the most enemies within landing radius. Ties go
## to the nearest cell. Returns {"cell": Vector2i, "count": enemies it would hit}.
func _best_cell(caster: BattleUnit) -> Dictionary:
	var grid := caster.grid
	var enemies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team:
			enemies.append(unit)
	var cells := grid.free_cells_in_range(caster.cell, throw_range_cells)
	cells.sort_custom(func(a, b): return grid.get_distance(caster.cell, a) < grid.get_distance(caster.cell, b))
	var best := {"cell": caster.cell, "count": 0}
	for cell in cells:
		var count := enemies.filter(func(e): return grid.get_distance(cell, e.cell) <= landing_radius_cells).size()
		if count > best["count"]:
			best = {"cell": cell, "count": count}
	return best


## This caster's bag if it's on the board, or null.
func _find_bag(caster: BattleUnit) -> BattleUnit:
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.is_summon and unit.get_credit_id() == caster.get_instance_id():
			for status in unit.statuses:
				if status is BagStatus:
					return unit
	return null

## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive and unit.is_inside_tree()   # off the board at battle end
