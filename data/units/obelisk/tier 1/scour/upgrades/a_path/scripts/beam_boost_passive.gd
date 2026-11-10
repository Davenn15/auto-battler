class_name BeamBoostPassive
extends Passive
## Scour's Cutting upgrades: his beam's damage and/or Wrack chance build up the longer it
## stays on one target, and reset when it switches. Needs a BeamPassive on the same unit;
## upgrade passives run after the unit's own, so the beam already exists.

## Extra damage per second of sustained fire (0.25 = +25%), up to Max Damage Ramp.
@export var damage_ramp_per_second: float = 0.0
@export var max_damage_ramp: float = 0.0
## Extra Wrack chance per second of sustained fire (0.1 = +10%), up to Max Wrack Ramp.
@export var wrack_ramp_per_second: float = 0.0
@export var max_wrack_ramp: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	for status in unit.statuses:
		if status is BeamStatus:
			status.damage_ramp_per_second += damage_ramp_per_second
			status.max_damage_ramp += max_damage_ramp
			status.wrack_ramp_per_second += wrack_ramp_per_second
			status.max_wrack_ramp += max_wrack_ramp
			return
	push_warning("%s: BeamBoostPassive found no beam to boost." % unit.name)
