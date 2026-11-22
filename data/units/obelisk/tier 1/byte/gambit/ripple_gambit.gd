class_name ByteRippleGambit
extends Gambit
## BYTE: a concussive ripple under its current target deals Damage (+ Insight Scaling of its
## Insight) as Damage Type and knocks it up for Knock Up seconds (see KnockUp). BYTE heals
## itself for Heal Share of its max health.
##   A1 (Health Scaling): the damage and knock-up time grow with the target's current health
##   %: up to +Health Scaling against a full-health target, nothing against an empty one.

@export var damage: float = 90.0
@export var insight_scaling: float = 0.5
@export var damage_type: int = Stats.DamageType.INSIGHT
@export var knock_up: float = 0.75
@export_range(0.0, 1.0, 0.01) var heal_share: float = 0.08
## A1: 0.5 = up to +50% damage and knock-up time against a full-health target.
@export var health_scaling: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return _target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var target := _target(caster)
	if target != null:
		var health_share := clampf(target.health / target.max_health, 0.0, 1.0) if target.max_health > 0.0 else 0.0
		var boost := 1.0 + health_scaling * health_share   # read before the hit lands
		var hit := Stats.scaled(damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT)) * boost
		var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
		ByteFx.ripple(target)
		var dealt := target.take_damage(BattleUnit.damage_bonus(caster, target, hit), wrack, damage_type)
		BattleUnit.gambit_damage_dealt(caster, target, dealt)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
		if target.alive:
			KnockUp.apply(target, knock_up * boost, caster)
	caster.heal(caster.max_health * heal_share, caster.get_instance_id())


## Its current target if it's alive, targetable and within its attack range.
func _target(caster: BattleUnit) -> BattleUnit:
	var target := caster.target
	if is_instance_valid(target) and target.alive and target.is_targetable() \
			and caster.grid.get_distance(caster.cell, target.cell) <= caster.attack_range:
		return target
	return null
