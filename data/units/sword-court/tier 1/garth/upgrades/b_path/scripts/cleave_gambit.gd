class_name CleaveGambit
extends Gambit
## Slashes every enemy within range, then shields the caster for each enemy hit.
## Gambit damage doesn't wrack and doesn't build charge.

const SLASH_COLOR := Color(1.0, 0.9, 0.6, 0.6)

@export var damage: float = 80.0
## Extra damage per point of the caster's Might.
@export var might_scaling: float = 0.8
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
@export var range_cells: int = 1
## Shield gained for each enemy the slash hits.
@export var shield_per_enemy: float = 80.0
@export var shield_duration: float = 4.0
## Seconds each enemy hit is stunned. 0 = no stun.
@export var stun_duration: float = 0.0


## Only casts if an enemy is in reach, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_range(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Enemies may have moved or died during the Act time, so look again now.
	var enemies := _enemies_in_range(caster)
	if enemies.is_empty():
		return
	_play_slash(caster)

	var hit_damage := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	# Gambit damage can wrack if an item lets it: one roll for the whole cleave.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit_damage *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var hits := 0
	for enemy in enemies:
		var dealt := enemy.take_damage(hit_damage, wrack, damage_type)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
		if dealt <= 0.0:
			continue   # dodged: no shield, no stun
		hits += 1
		enemy.stun(stun_duration, caster)
	caster.add_shield(shield_per_enemy * hits, shield_duration, caster.get_instance_id())


func _enemies_in_range(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team:
			continue
		if caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			result.append(unit)
	return result


## A ring that fades out around the caster, so you can see the slash.
func _play_slash(caster: BattleUnit) -> void:
	var radius := (range_cells + 0.5) * caster.grid.cell_spacing()
	var points := PackedVector2Array()
	for i in 24:
		points.append(Vector2.from_angle(TAU * i / 24.0) * radius)
	var ring := Polygon2D.new()
	ring.polygon = points
	ring.color = SLASH_COLOR
	ring.z_index = 10
	caster.get_tree().current_scene.add_child(ring)
	ring.global_position = caster.global_position
	var tween := ring.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ring.queue_free)
