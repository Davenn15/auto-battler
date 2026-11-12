class_name DischargeGambit
extends Gambit
## BATR.EE spends its Voltage on Volts: one for every Voltage Per Volt it has, each fired
## at a random enemy. Damage per Volt = Damage + Insight Scaling x Insight.
##   A1: Volts give Mono-Virus stacks.  A2: Volts silence.

@export var voltage_per_volt: float = 20.0
@export var damage: float = 90.0
@export var insight_scaling: float = 0.6
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 1
## Seconds between Volts.
@export var interval: float = 0.15
## A1: Mono-Virus stacks each Volt gives. 0 = none.
@export var virus_stacks: int = 0
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
	var color := MonoVirusStatus.SETTINGS.color if virus_stacks > 0 else VoltageStatus.COLOR
	for i in volts:
		var enemy := _random_enemy(caster)
		if enemy == null:
			break
		var level := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		var amount := hit * caster.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
		Volt.fire(caster.get_parent(), caster.global_position, enemy, color, i * interval,
				_on_volt_hit.bind(caster.get_instance_id(), amount, level))


## A Volt arrived: damage, then whatever the path adds.
func _on_volt_hit(target: BattleUnit, caster_id: int, amount: float, level: int) -> void:
	var caster := instance_from_id(caster_id) as BattleUnit
	if not _alive(target):
		return
	var dealt := target.take_damage(amount, level, damage_type, false, caster)
	target.get_tree().call_group("damage_tracker", "record_damage", caster_id, dealt)
	if dealt <= 0.0:
		return   # dodged
	if virus_stacks > 0 and target.alive:
		MonoVirusStatus.infect(target, virus_stacks, caster_id)
	if silence_time > 0.0 and target.alive:
		SilencedStatus.silence(target, silence_time)


## A random targetable enemy, or null.
func _random_enemy(caster: BattleUnit) -> BattleUnit:
	var enemies: Array = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable():
			enemies.append(unit)
	return CombatRng.pick(enemies) if not enemies.is_empty() else null


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
