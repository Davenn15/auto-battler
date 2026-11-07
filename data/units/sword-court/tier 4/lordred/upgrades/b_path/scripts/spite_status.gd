class_name SpiteStatus
extends Status
## Whenever an enemy attacks the unit, it flings a blade shard back at that enemy.
## Shards aren't attacks: they don't build charge, trigger on-hit effects, or provoke
## shards of their own.

const SHARD_COLOR := Color(0.713, 0.16, 0.277, 1.0)

var damage: float
var might_scaling: float


func _init(p_damage: float, p_might_scaling: float) -> void:
	damage = p_damage
	might_scaling = p_might_scaling


func on_attacked(unit: BattleUnit, attacker: BattleUnit, dealt: float) -> void:
	if not unit.alive or not is_instance_valid(attacker) or not attacker.alive:
		return
	var amount := Stats.scaled(damage, might_scaling, unit.get_stat(Stats.Stat.MIGHT))
	amount += dealt * _attack_share(unit)
	var shard := Projectile.new()
	shard.setup(unit, attacker, amount, SHARD_COLOR, 0, unit.get_attack_damage_type())
	shard.is_attack = false
	shard.grants_charge = false
	unit.get_tree().current_scene.add_child(shard)
	shard.global_position = unit.global_position


## Extra shard damage as a share of the attack that triggered it, from statuses that give
## shard_attack_share (B2).
static func _attack_share(unit: BattleUnit) -> float:
	var total := 0.0
	for status in unit.statuses:
		if "shard_attack_share" in status:
			total += status.shard_attack_share
	return total
