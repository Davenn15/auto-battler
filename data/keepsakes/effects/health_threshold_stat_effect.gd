class_name HealthThresholdStatEffect
extends Passive
## While the unit's health is above (or below) a share of its max health, some stats get
## a flat bonus or a percentage boost.

@export var stats: Array[Stats.Stat] = [Stats.Stat.CELERITY]
## Added to each stat while active.
@export var flat: float = 0.0
## Each stat is multiplied by 1 + this while active (0.3 = +30%).
@export var percent: float = 0.0
## Share of max health that switches it (0.5 = half).
@export_range(0.0, 1.0, 0.05) var threshold: float = 0.5
## True: active while above the threshold. False: active while below it.
@export var while_above: bool = true
## What shows while it's active.
enum Visual { NONE, WIND, BRICKS }
@export var visual: Visual = Visual.NONE


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Threshold.new(self))


class Threshold extends Status:
	var effect: HealthThresholdStatEffect

	func _init(p_effect: HealthThresholdStatEffect) -> void:
		effect = p_effect

	func _active(unit: BattleUnit) -> bool:
		var share := unit.health / unit.max_health if unit.max_health > 0.0 else 0.0
		return share > effect.threshold if effect.while_above else share < effect.threshold

	var _shown := false   # whether the visual is showing

	func tick(unit: BattleUnit, _delta: float) -> void:
		var on := _active(unit)
		if effect.visual != Visual.NONE and on != _shown:
			_shown = on
			KeepsakeVfx.set_threshold_visual(unit, effect.visual, on)

	func on_removed(unit: BattleUnit) -> void:
		if _shown:
			KeepsakeVfx.set_threshold_visual(unit, effect.visual, false)

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if effect.flat != 0.0 and stat in effect.stats and _active(unit):
			return value + effect.flat
		return value

	## Percentages go in the final pass, so they boost the stat after every flat bonus.
	func modify_final_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if effect.percent != 0.0 and stat in effect.stats and _active(unit):
			return value * (1.0 + effect.percent)
		return value
