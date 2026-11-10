class_name SerratedGambit
extends Gambit
## Glaive spins like a sawblade for a while, damaging every enemy next to him over and over.
## He can't attack or gain Charge while spinning, but he can still move (see SpinStatus).
## Each tick = Damage + Celerity Scaling x Celerity, fixed when cast.

@export var duration: float = 4.0
@export var radius_cells: int = 1
## Seconds between spin hits.
@export var tick_time: float = 0.25
@export var damage: float = 15.0
@export var celerity_scaling: float = 0.15
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 2
## B1: chance to deflect each incoming shot back at its shooter while spinning.
@export var deflect_chance: float = 0.0
## B2: each spin hit bleeds the enemy for this share of its max health per second (0.005 = 0.5%).
@export var bleed_percent: float = 0.0
@export var bleed_duration: float = 3.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for status in caster.statuses.duplicate():
		if status is SpinStatus:
			caster.remove_status(status)
	var spin := SpinStatus.new(duration, radius_cells, tick_time,
			Stats.scaled(damage, celerity_scaling, caster.get_stat(Stats.Stat.CELERITY)), damage_type)
	spin.deflect_chance = deflect_chance
	spin.bleed_percent = bleed_percent
	spin.bleed_duration = bleed_duration
	caster.add_status(spin)
	caster.show_float_text("Serrated", GlaiveRotor.ROTOR_COLOR)
