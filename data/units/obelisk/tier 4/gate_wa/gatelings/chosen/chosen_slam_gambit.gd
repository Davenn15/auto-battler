class_name ChosenSlamGambit
extends Gambit
## Chosen Gateling: shields itself, lifts every enemy next to it into the air (they can't
## act), then slams them down for a share of their max health as Might damage.
## Shield = Shield + Shield Insight Scaling x Insight.

@export var shield: float = 200.0
@export var shield_insight_scaling: float = 1.0
@export var shield_duration: float = 4.0
@export var radius_cells: int = 1
## Seconds the enemies hang in the air before the slam.
@export var lift_time: float = 0.8
## Share of each enemy's max health the slam deals (0.15 = 15%).
@export var max_health_share: float = 0.15


func can_use(caster: BattleUnit) -> bool:
	return not _enemies_near(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var insight := caster.get_stat(Stats.Stat.INSIGHT)
	caster.add_shield(Stats.scaled(shield, shield_insight_scaling, insight), shield_duration, caster.get_credit_id())
	var lifted := _enemies_near(caster)
	for enemy in lifted:
		enemy.stun(lift_time, caster)
		_lift_look(enemy)
	caster.show_float_text("Ascend", GateRules.LIGHT)
	await caster.get_tree().create_timer(lift_time, false, true).timeout
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		return
	for enemy in lifted:
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var dealt := enemy.take_damage(enemy.max_health * max_health_share, 0, Stats.DamageType.MIGHT, false, caster)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
		KeepsakeVfx.missile_blast(enemy.get_parent(), enemy.global_position, 26.0, GateRules.COLOR)


func _enemies_near(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or not unit.active or unit.team == caster.team:
			continue
		if caster.grid.get_distance(caster.cell, unit.cell) <= radius_cells:
			result.append(unit)
	return result


## Raises the enemy's sprite and drops it back down for the slam (looks only).
func _lift_look(enemy: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or enemy.sprite == null:
		return
	var start := enemy.sprite.position
	var tween := enemy.sprite.create_tween()
	tween.tween_property(enemy.sprite, "position", start + Vector2(0, -26), lift_time * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(enemy.sprite, "position", start, lift_time * 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
