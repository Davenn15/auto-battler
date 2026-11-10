class_name PoppingGambit
extends Gambit
## Bubbler blows several bubbles that float to the most hurt allies nearby (by share of max
## health, himself included) and shield them. Each bubble pops when its shield breaks or
## runs out, damaging every enemy next to that ally (see BubbleShieldStatus). If there are
## more bubbles than allies, the extras go round again, most hurt first.
## Pop damage = Pop Damage + Pop Might Scaling x Might, fixed when blown.

@export var bubbles: int = 3
## How far away an ally can be to get a bubble, in hex cells.
@export var range_cells: int = 4
@export var shield_amount: float = 150.0
@export var shield_duration: float = 5.0
@export var pop_damage: float = 80.0
@export var pop_might_scaling: float = 0.5
@export var pop_radius_cells: int = 1
## B1: seconds the pop stuns. 0 = none.
@export var pop_stun: float = 0.0
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## Seconds a bubble takes to float to its ally.
@export var flight_time: float = 0.45


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var allies := _allies_by_hurt(caster)
	if allies.is_empty():
		return
	var damage := Stats.scaled(pop_damage, pop_might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	caster.show_float_text("Bubbles", BubbleZone.BUBBLE_COLOR)
	for i in bubbles:
		_blow(caster, allies[i % allies.size()], damage)


## Living allies within range, himself included, most hurt (lowest share of health) first.
func _allies_by_hurt(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team == caster.team \
				and caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			result.append(unit)
	result.sort_custom(func(a, b): return a.health / a.max_health < b.health / b.max_health)
	return result


## Sends one bubble floating to `ally`; the shield goes on when it arrives.
func _blow(caster: BattleUnit, ally: BattleUnit, damage: float) -> void:
	var caster_id := caster.get_instance_id()
	var team := caster.team
	var orb := Node2D.new()   # invisible when there's no screen (simulations)
	if KeepsakeVfx.enabled():
		var shell := BubbleShieldStatus.BubbleShell.new()
		shell.radius = 7.0
		orb = shell
	orb.z_index = 12
	caster.get_tree().current_scene.add_child(orb)
	orb.global_position = caster.global_position
	var tween := orb.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(orb, "global_position", ally.global_position, flight_time)
	tween.tween_callback(func():
		orb.queue_free()
		if not is_instance_valid(ally) or not ally.alive:
			return
		_shield(ally, caster_id, team, damage)
	)


func _shield(ally: BattleUnit, caster_id: int, team: int, damage: float) -> void:
	# Like BattleUnit.add_shield (Wracked healing, shield boosts), but with a bubble that pops.
	var amount := shield_amount
	var giver: BattleUnit = instance_from_id(caster_id) as BattleUnit if is_instance_id_valid(caster_id) else null
	if giver != null:
		amount *= giver.effect_wrack_multiplier(giver.roll_effect_wrack(Stats.EffectKind.HEALING), Stats.EffectKind.HEALING)
	for status in ally.statuses:
		amount = status.modify_shield_received(ally, amount)
	if amount <= 0.0:
		return
	var bubble := BubbleShieldStatus.new(amount, shield_duration)
	bubble.caster_id = caster_id
	bubble.team = team
	bubble.pop_damage = damage
	bubble.pop_radius_cells = pop_radius_cells
	bubble.pop_stun = pop_stun
	bubble.damage_type = damage_type
	ally.add_status(bubble)
	ally.get_tree().call_group("damage_tracker", "record_shielding", caster_id, amount)
