class_name ShatterGambit
extends Gambit
## Two moves:
##   Rebuild: the first time she casts with no shield, she floats up out of reach
##            (untargetable) and slowly rebuilds her whole start-of-game shield, then
##            rejoins the fight. Once per combat.
##   Shatter: every other cast, shielded or not, she gains a shield, channels, then
##            shatters up to Max Sacrifice of it, hurting every nearby enemy for a share
##            of what was sacrificed

const SHATTER_COLOR := Color(1.0, 1.0, 1.0, 1.0)   # the same pure gold as the twinsword

@export_group("Shatter (shielded)")
@export var shield_gain: float = 400.0
## Seconds spent channelling before the shatter.
@export var channel_time: float = 1.5
## How far the shatter reaches, in hex cells.
@export var radius_cells: int = 2
## Most shield one shatter can use up. Anything above this stays on her.
@export var max_sacrifice: float = 500.0
## Damage to each enemy no matter how much shield was sacrificed, even none.
@export var base_damage: float = 100.0
## Extra damage per point of shield sacrificed (0.65 = 65% of it).
@export var damage_share: float = 0.65
## Seconds the shatter stuns every enemy it damages.
@export var stun_time: float = 0.75



@export_group("Rebuild (unshielded)")
## Seconds the rebuild takes. She's untargetable and can't act meanwhile.
@export var rebuild_time: float = 3.0
## How high she floats while rebuilding, in pixels.
@export var float_height: float = 14.0


func can_use(caster: BattleUnit) -> bool:
	if _wants_rebuild(caster):
		return true
	return not _enemies_in_reach(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	if _wants_rebuild(caster):
		await _rebuild(caster)
	else:
		await _shatter(caster)


## True the first time she casts with no shield; after that, never.
func _wants_rebuild(caster: BattleUnit) -> bool:
	var purity := _purity(caster)
	return purity != null and not purity.rebuilt and purity.starting_shield > 0.0 \
			and caster.get_shield() <= 0.0


# ---------- Shielded: shatter ----------

func _shatter(caster: BattleUnit) -> void:
	caster.add_shield(shield_gain, INF, caster.get_instance_id())
	caster.lock_for(channel_time)
	await caster.get_tree().create_timer(channel_time, true, true).timeout
	if not _alive(caster) or not caster.active:
		return
	var sacrificed := _drain_shield(caster, max_sacrifice)
	_play_shatter(caster)
	var amount := base_damage + sacrificed * damage_share
	# Gambit damage can wrack if an item lets it: one roll for the whole shatter.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	amount *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var ignore := caster.ignores_wards()   # true if the shatter used up all her shield
	for enemy in _enemies_in_reach(caster):
		var dealt := enemy.take_damage(amount, wrack, caster.get_attack_damage_type(), ignore)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
		if stun_time > 0.0 and dealt > 0.0 and enemy.alive:
			enemy.stun(stun_time, caster)


## Takes up to `amount` of shield off the caster, from her shields in order, and returns
## how much it took.
func _drain_shield(caster: BattleUnit, amount: float) -> float:
	var taken := 0.0
	for status in caster.statuses:
		if taken >= amount:
			break
		if status is ShieldStatus:
			var bite := minf(status.shield, amount - taken)
			status.shield -= bite
			taken += bite
	return taken


# ---------- Unshielded: rebuild ----------

func _rebuild(caster: BattleUnit) -> void:
	var purity := _purity(caster)
	purity.rebuilt = true   # once per combat, even if she's interrupted
	var target := purity.starting_shield
	# Anything that changes shields received (overtime, for one) applies to the rebuild too.
	for status in caster.statuses:
		target = status.modify_shield_received(caster, target)
	if target <= 0.0:
		return
	var shield := ShieldStatus.new(0.0, INF)   # grows from nothing as she rebuilds
	caster.add_status(shield)
	var airborne := UntargetableStatus.new(INF)   # removed by hand when she lands
	caster.add_status(airborne)
	caster.lock_for(rebuild_time + 0.1)
	_float(caster, -float_height)
	var elapsed := 0.0
	while elapsed < rebuild_time:
		if not _alive(caster) or not caster.is_inside_tree() or not caster.active:
			break
		await caster.get_tree().physics_frame
		elapsed += caster.get_physics_process_delta_time()
		shield.shield = target * minf(elapsed / rebuild_time, 1.0)
	if _alive(caster) and caster.is_inside_tree():
		caster.remove_status(airborne)
		_float(caster, float_height)
		caster.get_tree().call_group("damage_tracker", "record_shielding", caster.get_instance_id(), shield.shield)


## Her passive's status, which remembers her starting shield and whether she's rebuilt.
func _purity(caster: BattleUnit) -> PurityStatus:
	for status in caster.statuses:
		if status is PurityStatus:
			return status
	return null

## The shield she started the battle with, as her passive recorded it. 0 if unknown.
func _starting_shield(caster: BattleUnit) -> float:
	for status in caster.statuses:
		if status is PurityStatus:
			return status.starting_shield
	return 0.0


## Moves her sprite up or down by `amount` pixels over a moment, for the float.
func _float(caster: BattleUnit, amount: float) -> void:
	if caster.sprite != null:
		caster.sprite.create_tween().tween_property(caster.sprite, "position:y", amount, 0.3).as_relative()


# ---------- Shared ----------

func _enemies_in_reach(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team \
				and caster.grid.get_distance(caster.cell, unit.cell) <= radius_cells:
			result.append(unit)
	return result


## A gold ring that bursts outward and fades.
func _play_shatter(caster: BattleUnit) -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = SHATTER_COLOR
	var r := (radius_cells + 0.5) * caster.grid.cell_spacing()
	var points := PackedVector2Array()
	for i in 33:
		points.append(Vector2.from_angle(TAU * i / 32.0) * r)
	ring.points = points
	ring.scale = Vector2.ONE * 0.3
	caster.get_tree().current_scene.add_child(ring)
	ring.global_position = caster.global_position
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.25)
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
