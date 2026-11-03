class_name ArcaneBladesGambit
extends Gambit
## Channels arcane blades that orbit the caster for the rest of combat. Each time the
## caster attacks, every blade fires its own shot at the same target. Casting again
## adds more blades, up to a cap.

@export var blades_per_cast: int = 3
@export var max_blades: int = 6
## Each blade shot = Blade Damage + Blade Insight Scaling x the caster's Insight.
@export var blade_damage: float = 15.0
@export var blade_insight_scaling: float = 0.15
## Charge the caster gains each time a blade shot lands. 0 = none.
@export var charge_per_blade_hit: float = 0.0
## Shield the caster gains on each cast = Shield Amount + Shield Insight Scaling x Insight. 0 = none.
@export var shield_amount: float = 0.0
@export var shield_insight_scaling: float = 0.0
@export var shield_duration: float = 4.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var blades := _find_blades(caster)
	if blades == null:
		blades = ArcaneBladesStatus.new(blade_damage, blade_insight_scaling, charge_per_blade_hit)
		caster.add_status(blades)
	blades.add_blades(caster, mini(blades_per_cast, max_blades - blades.blade_count()))
	if shield_amount > 0.0:
		var shield := Stats.scaled(shield_amount, shield_insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
		caster.add_shield(shield, shield_duration, caster.get_instance_id())


## The caster's blades from an earlier cast, or null if this is the first.
func _find_blades(caster: BattleUnit) -> ArcaneBladesStatus:
	for status in caster.statuses:
		if status is ArcaneBladesStatus:
			return status
	return null
