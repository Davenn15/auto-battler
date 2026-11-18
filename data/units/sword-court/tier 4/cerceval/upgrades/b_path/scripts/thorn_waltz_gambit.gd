class_name ThornWaltzGambit
extends Gambit
## Cerceval B: twirls his barbed blades around him, dealing Damage + Celerity Scaling x
## Celerity (Celerity damage) to every enemy within Radius Cells. It's Gambit damage, so
## Bloodletter makes it Bleed.
##   B2: then every enemy it damaged takes all the Bleed left in its pool at once (the Bleed
##       this hit just added included).

@export var damage: float = 150.0
@export var celerity_scaling: float = 0.6
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 2
@export var radius_cells: int = 1
## B2: 1 = enemies it damages take all their stored Bleed at once.
@export var burst_bleed: float = 0.0


## Only when the twirl would catch someone.
func can_use(caster: BattleUnit) -> bool:
	return not _enemies_near(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var enemies := _enemies_near(caster)
	if enemies.is_empty():
		BladehookGambit.refund(caster)   # everyone left reach during the wind-up
		return
	CercevalFx.waltz(caster, (radius_cells + 0.6) * caster.grid.cell_spacing())
	var amount := Stats.scaled(damage, celerity_scaling, caster.get_stat(Stats.Stat.CELERITY))
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	amount *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	for enemy in enemies:
		var dealt := enemy.take_damage(BattleUnit.damage_bonus(caster, enemy, amount), wrack, damage_type)
		BattleUnit.gambit_damage_dealt(caster, enemy, dealt)   # Gambit damage (see BattleUnit)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
		if burst_bleed > 0.0 and dealt > 0.0 and enemy.alive:
			Bleed.burst(enemy)


func _enemies_near(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and caster._is_valid_target(unit) and caster.grid.get_distance(caster.cell, unit.cell) <= radius_cells:
			result.append(unit)
	return result
