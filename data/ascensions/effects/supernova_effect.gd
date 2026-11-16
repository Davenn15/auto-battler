class_name SupernovaEffect
extends Passive
## An Ascension effect (Supernova, for Vere): her Starburn lasts Duration seconds, ramping
## on the same curve the whole time (so it deals more), and each burn that runs its full
## length bursts, dealing Burst Share of each nearby enemy's max health as Insight damage
## within Burst Radius cells of the target.

@export var duration: float = 3.5
@export_range(0.0, 0.5, 0.005) var burst_share: float = 0.04
@export var burst_radius: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	for status in unit.statuses:
		if status is StarburnStatus:
			if status.ramp_time <= 0.0:
				status.ramp_time = status.duration   # keep the normal ramp, just for longer
			status.duration = maxf(status.duration, duration)
			status.burst_share = burst_share
			status.burst_radius = burst_radius
