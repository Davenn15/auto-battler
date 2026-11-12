class_name SlimStrikeGambit
extends Gambit
## Slim Gateling: a heavy Celerity strike on its target, harder the more hurt the target is.
## Damage = (Damage + Celerity Scaling x Celerity) x (1 + Execute Bonus x share of the
## target's health missing): the base at full health, up to 1 + Execute Bonus times as
## much near death.

@export var damage: float = 90.0
@export var celerity_scaling: float = 1.0
@export var execute_bonus: float = 1.5


func can_use(caster: BattleUnit) -> bool:
	var target := caster.target
	return target != null and target.alive and caster.grid.get_distance(caster.cell, target.cell) <= caster.attack_range


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var target := caster.target
	if target == null or not target.alive:
		return
	var missing := 1.0 - clampf(target.health / target.max_health, 0.0, 1.0)
	var amount := Stats.scaled(damage, celerity_scaling, caster.get_stat(Stats.Stat.CELERITY)) * (1.0 + execute_bonus * missing)
	var dealt := target.take_damage(amount, 0, Stats.DamageType.CELERITY, false, caster)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
	KeepsakeVfx.cleave_slash(target)
