class_name RailgunGambit
extends Gambit
## BATR.EE B (Magnetic): charges up for the cast time, building its own Voltage at Charge
## Voltage Multiplier times the normal rate meanwhile (see GridPassive), then spends all its
## Voltage on one railgun shot at the enemy within its attack range with the highest Might,
## dealing Insight damage. Damage = Damage + Voltage spent x (Per Voltage + Per Voltage
## Insight x Insight).
##   B1 (Max Health Share): the shot deals that share of the target's max health on top.
##   B2 (Kill Charge Share, Kill Voltage): if the shot kills, BATR.EE gets that share of its
##   Charge back right away and that much Voltage once the Gambit is over.

@export var damage: float = 160.0
@export var per_voltage: float = 2.5
@export var per_voltage_insight: float = 0.02
@export var charge_voltage_multiplier: float = 5.0
## B1: share of the target's max health the shot deals on top (0.2 = +20%). 0 = none.
@export_range(0.0, 1.0, 0.05) var max_health_share: float = 0.0
## B2: share of max Charge back on a kill (0.5 = half). 0 = none.
@export_range(0.0, 1.0, 0.05) var kill_charge_share: float = 0.0
## B2: Voltage gained on a kill, given after the Gambit clears its stacks.
@export var kill_voltage: float = 0.0

const COLOR := Color(0.7, 0.85, 1.0)


func can_use(caster: BattleUnit) -> bool:
	return _strongest_enemy(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var target := _strongest_enemy(caster)
	if target == null:
		return
	var voltage := VoltageStatus.ensure(caster)
	var spent := floorf(voltage.stacks)
	voltage.spend(spent)
	var amount := damage + spent * (per_voltage + per_voltage_insight * caster.get_stat(Stats.Stat.INSIGHT))
	amount += target.max_health * max_health_share   # B1
	var level := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	amount *= caster.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
	_beam(caster, target)
	var dealt := target.take_damage(amount, level, Stats.DamageType.INSIGHT, false, caster)
	BattleUnit.gambit_damage_dealt(caster, target, dealt)   # Gambit damage (see BattleUnit)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
	caster.show_float_text("Railgun x%d" % int(spent), COLOR)
	if dealt > 0.0 and not target.alive and (kill_charge_share > 0.0 or kill_voltage > 0.0):
		caster.charge = minf(caster.charge + caster.max_charge * kill_charge_share, caster.max_charge)
		caster._update_charge_bar()
		voltage.after_gambit += kill_voltage
		caster.show_float_text("Overcharge", COLOR)


## The living, targetable enemy within its attack range with the most Might.
func _strongest_enemy(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or unit.team == caster.team or not unit.is_targetable():
			continue
		if caster.grid.get_distance(caster.cell, unit.cell) > caster.attack_range:
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
