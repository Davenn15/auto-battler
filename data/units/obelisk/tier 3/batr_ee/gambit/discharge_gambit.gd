class_name DischargeGambit
extends Gambit
## BATR.EE: for every Voltage Per Volt Voltage it has, it spends them and fires a Volt at a
## random enemy within Range Cells. Damage per Volt = Damage + Insight Scaling x Insight.
## Whatever Voltage is left over is cleared when the Gambit finishes, as for everyone.
##   A1: Volts shred Insight Ward (stacking, each for its own Shred Duration).
##   A2: Volts Silence enemies hit.

@export var voltage_per_volt: float = 10.0
@export var range_cells: int = 3
@export var damage: float = 90.0
@export var insight_scaling: float = 0.6
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 1
## Seconds between Volts.
@export var interval: float = 0.15
## A1: Insight Ward each Volt hit takes off for Shred Duration seconds. Hits stack. 0 = none.
@export var insight_ward_shred: float = 0.0
@export var shred_duration: float = 4.0
## A2: seconds each Volt silences its target (no Gambit, no Charge). 0 = none.
@export var silence_time: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	if _random_enemy(caster) == null:
		return false
	var voltage := VoltageStatus.of(caster)
	return voltage != null and voltage.stacks >= voltage_per_volt


func execute(caster: BattleUnit) -> void:
	if not _alive(caster) or not caster.is_inside_tree():
		return
	var voltage := VoltageStatus.of(caster)
	if voltage == null:
		return
	var volts := floori(voltage.stacks / voltage_per_volt)
	if volts <= 0:
		return
	voltage.spend(volts * voltage_per_volt)
	caster.show_float_text("Discharge x%d" % volts, VoltageStatus.LIGHT)
	var hit := Stats.scaled(damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
	for i in volts:
		var enemy := _random_enemy(caster)
		if enemy == null:
			break
		var level := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		var amount := hit * caster.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
		Volt.fire(caster.get_parent(), caster.global_position, enemy, VoltageStatus.COLOR, i * interval,
				_on_volt_hit.bind(caster.get_instance_id(), amount, level))


## A Volt arrived: damage, then whatever the path adds.
func _on_volt_hit(target: BattleUnit, caster_id: int, amount: float, level: int) -> void:
	var caster := instance_from_id(caster_id) as BattleUnit
	if not _alive(target):
		return
	var dealt := target.take_damage(amount, level, damage_type, false, caster)
	BattleUnit.gambit_damage_dealt(caster, target, dealt)   # Gambit damage (see BattleUnit)
	target.get_tree().call_group("damage_tracker", "record_damage", caster_id, dealt)
	if dealt <= 0.0:
		return   # dodged
	if insight_ward_shred > 0.0 and target.alive:
		WardShiftStatus.shred(caster, target, Stats.Stat.INSIGHT_WARD, insight_ward_shred, shred_duration)
	if silence_time > 0.0 and target.alive:
		Silence.apply(target, silence_time, caster)


## A random targetable enemy within Range Cells, or null.
func _random_enemy(caster: BattleUnit) -> BattleUnit:
	var enemies: Array = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable() \
				and caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			enemies.append(unit)
	return CombatRng.pick(enemies) if not enemies.is_empty() else null


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
