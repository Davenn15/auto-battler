class_name DischargeGambit
extends Gambit
## BATR.EE spends its Voltage on Volts: one for every Voltage Per Volt it has, each fired
## at a random enemy. Damage per Volt = Damage + Insight Scaling x Insight.
##   A (Charged): a shield on cast.  A2: a shield whenever a Volt hits.
##   B (Corrupted, its own Gambit .tres): Phases first (gaining Voltage while Phased, from
##       its passive), then fires Mono-Virus Volts that also give Mono-Virus stacks.
##   B1: Volts silence.  B2: a Volt doubles Mono-Virus stacks already there instead.

@export var voltage_per_volt: float = 50.0
## Voltage gained when cast, before the Volts are counted.
@export var voltage_on_cast: float = 0.0
@export var damage: float = 70.0
@export var insight_scaling: float = 0.6
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 1
## Seconds between Volts.
@export var interval: float = 0.15
@export_group("Charged (A)")
## A: shield on cast, as a share of max health (0.3 = 30%), and how long it lasts.
@export_range(0.0, 1.0, 0.05) var cast_shield_share: float = 0.0
@export var cast_shield_duration: float = 5.0
## A2: shield gained whenever a Volt hits, and how long it lasts.
@export var hit_shield: float = 0.0
@export var hit_shield_duration: float = 4.0
@export_group("Corrupted (B)")
## B: seconds BATR.EE Phases before firing. 0 = no Phase.
@export var phase_time: float = 0.0
## B: Mono-Virus stacks each Volt gives.
@export var virus_stacks: int = 0
## B1: seconds each Volt silences its target (no Gambit, no Charge). 0 = none.
@export var silence_time: float = 0.0
## B2: 1 = a Volt doubles a target's Mono-Virus stacks if it has any, instead of adding.
@export var double_virus: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	if _random_enemy(caster) == null:
		return false
	if phase_time > 0.0:
		return true   # it gains Voltage while Phased
	var voltage := VoltageStatus.of(caster)
	return voltage != null and voltage.stacks + voltage_on_cast >= voltage_per_volt


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	if cast_shield_share > 0.0:
		caster.add_shield(caster.max_health * cast_shield_share, cast_shield_duration, caster.get_instance_id())
	if phase_time > 0.0:
		PhaseStatus.phase(caster, phase_time)
		# Fires once the Phase ends, which is sooner if it has no fighting teammates.
		while _alive(caster) and caster.active and caster.is_inside_tree() and PhaseStatus.is_phased(caster):
			await caster.get_tree().physics_frame
		if not _alive(caster) or not caster.active or not caster.is_inside_tree():
			return
	var voltage := VoltageStatus.of(caster)
	if voltage == null:
		return
	if voltage_on_cast > 0.0:
		voltage.add(voltage_on_cast)
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
		var had := MonoVirusStatus.stacks_on(target)
		var extra := had if double_virus > 0.0 and had > 0 else virus_stacks
		MonoVirusStatus.infect(target, extra, caster_id)
	if silence_time > 0.0 and target.alive:
		SilencedStatus.silence(target, silence_time)
	if hit_shield > 0.0 and _alive(caster):
		caster.add_shield(hit_shield, hit_shield_duration, caster_id)


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
