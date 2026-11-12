class_name RailgunGambit
extends Gambit
## BATR.EE B (Magnetic): charges up (the cast time), then spends all its Voltage on one
## railgun shot at the enemy with the highest Might, dealing Insight damage.
## Damage = Damage + Voltage spent x (Per Voltage + Per Voltage Insight x Insight).
##   B2: if the shot leaves the target at or below Execute Threshold of its max health,
##       it dies.

@export var damage: float = 50.0
@export var per_voltage: float = 1.0
@export var per_voltage_insight: float = 0.01
## The least Voltage worth firing for.
@export var min_voltage: float = 40.0
## B2: share of max health at or below which the shot finishes the target (0.2 = 20%).
## 0 = no execute.
@export_range(0.0, 1.0, 0.05) var execute_threshold: float = 0.0

const COLOR := Color(0.7, 0.85, 1.0)


func can_use(caster: BattleUnit) -> bool:
	var voltage := VoltageStatus.of(caster)
	return voltage != null and voltage.stacks >= min_voltage and _strongest_enemy(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var voltage := VoltageStatus.of(caster)
	var target := _strongest_enemy(caster)
	if voltage == null or target == null:
		return
	var spent := voltage.stacks
	voltage.spend(spent)
	var amount := damage + spent * (per_voltage + per_voltage_insight * caster.get_stat(Stats.Stat.INSIGHT))
	var level := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	amount *= caster.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
	_beam(caster, target)
	var dealt := target.take_damage(amount, level, Stats.DamageType.INSIGHT, false, caster)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
	caster.show_float_text("Railgun", COLOR)
	if execute_threshold > 0.0 and dealt > 0.0 and target.alive \
			and target.health <= target.max_health * execute_threshold:
		target.show_float_text("Executed", COLOR)
		target.kill()


## The living, targetable enemy with the most Might.
func _strongest_enemy(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable():
			continue
		if best == null or unit.get_stat(Stats.Stat.MIGHT) > best.get_stat(Stats.Stat.MIGHT):
			best = unit
	return best


## A bright straight beam from BATR.EE to the target that fades fast (looks only).
func _beam(caster: BattleUnit, target: BattleUnit) -> void:
	if not KeepsakeVfx.enabled():
		return
	var beam := RailBeam.new()
	beam.z_index = 14
	beam.to = target.global_position - caster.global_position
	caster.get_parent().add_child(beam)
	beam.global_position = caster.global_position
	KeepsakeVfx.burst(target, COLOR)


class RailBeam extends Node2D:
	const LIFE := 0.35
	var to := Vector2.ZERO
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - _age / LIFE
		draw_line(Vector2.ZERO, to, Color(RailgunGambit.COLOR, 0.5 * fade), 10.0 * fade + 2.0, true)
		draw_line(Vector2.ZERO, to, Color(1, 1, 1, fade), 3.0 * fade + 1.0, true)
