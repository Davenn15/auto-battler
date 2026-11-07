class_name ExplosiveShotGambit
extends MerriboldGambit
## Fires an explosive shot that bursts in a thin cone in front of the caster. Closer
## enemies take more: Close Multiplier right next to her, falling to Far Multiplier at
## the cone's tip. Uses MerriboldGambit's cone, aiming, and damage settings.

## Damage multiplier for an enemy right next to her.
@export var close_multiplier: float = 1.5
## Damage multiplier for an enemy at the edge of the cone.
@export var far_multiplier: float = 0.5
## Might the caster gains for the rest of combat each time she casts. 0 = none.
@export var might_per_cast: float = 0.0
## Share of the damage dealt that heals the caster (0.4 = 40%). 0 = none.
@export_range(0.0, 2.0, 0.05) var lifesteal: float = 0.0

func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Enemies may have moved or died during the Act time, so look again now.
	var enemies := _enemies_in_range(caster)
	if enemies.is_empty():
		return
	var aim := _best_direction(caster, enemies)
	_play_swing_visual(caster, aim)
	var hit_damage := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	# Gambit damage can wrack if an item lets it: one roll for the whole blast.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit_damage *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var reach := range_cells * caster.grid.cell_spacing()
	var total := 0.0
	for enemy in _enemies_in_cone(caster, enemies, aim):
		if not enemy.alive:
			continue
		# 0 right next to her, 1 at the cone's tip.
		var how_far := clampf(caster.global_position.distance_to(enemy.global_position) / reach, 0.0, 1.0)
		var amount := hit_damage * lerpf(close_multiplier, far_multiplier, how_far)
		var dealt := enemy.take_damage(amount, wrack, damage_type)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
		total += dealt
	if lifesteal > 0.0:
		caster.heal(total * lifesteal, caster.get_instance_id())
	if might_per_cast > 0.0:
		caster.add_status(PermanentStatStatus.new(Stats.Stat.MIGHT, might_per_cast))
