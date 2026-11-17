class_name StatOnEventEffect
extends Passive
## Each time something happens (a kill, an attack, a Gambit, an attack landing), the unit
## gains a stat. HIT is a Hit Effect: it happens when the attack lands, not when it's made.
## With a duration it's temporary; without one it stacks for the rest of combat.

enum Event { KILL, ATTACK, GAMBIT, HIT }

@export var event: Event = Event.KILL
@export var stat: Stats.Stat = Stats.Stat.MIGHT
@export var amount: float = 10.0
## Seconds each gain lasts. 0 = for the rest of combat, stacking.
@export var duration: float = 0.0
## What shows when it triggers. Glows grow with each stack.
enum Visual { NONE, RED_GLOW, BLUE_GLOW, RED_CIRCLE }
@export var visual: Visual = Visual.NONE


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Tracker.new(self))


## The unit's running total, and what triggers it.
class Tracker extends Status:
	var effect: StatOnEventEffect
	var stacked: float = 0.0   # the permanent gains so far

	func _init(p_effect: StatOnEventEffect) -> void:
		effect = p_effect

	func on_kill(unit: BattleUnit, _victim: BattleUnit) -> void:
		if effect.event == Event.KILL:
			_gain(unit)

	func on_attack(unit: BattleUnit) -> void:
		if effect.event == Event.ATTACK:
			_gain(unit)

	func on_gambit(unit: BattleUnit) -> void:
		if effect.event == Event.GAMBIT:
			_gain(unit)

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return GainHit.new(self, unit) if effect.event == Event.HIT else null

	func _gain(unit: BattleUnit) -> void:
		if effect.duration > 0.0:
			unit.add_status(TimedStatStatus.new(effect.stat, effect.amount, effect.duration))
		else:
			stacked += effect.amount
			unit.gain_permanent_stats({effect.stat: effect.amount})
		_count += 1
		_show(unit)

	var _count := 0   # times it has triggered this combat

	func _show(unit: BattleUnit) -> void:
		match effect.visual:
			Visual.RED_GLOW:
				KeepsakeVfx.set_glow(unit, "VfxRedGlow", KeepsakeVfx.KILL_GLOW, KeepsakeVfx.stack_strength(_count))
			Visual.BLUE_GLOW:
				KeepsakeVfx.set_glow(unit, "VfxBlueGlow", KeepsakeVfx.INSIGHT_GLOW, KeepsakeVfx.stack_strength(_count))
			Visual.RED_CIRCLE:
				KeepsakeVfx.ward_circle(unit, effect.duration)

	func on_removed(unit: BattleUnit) -> void:
		KeepsakeVfx.clear(unit, "VfxRedGlow")
		KeepsakeVfx.clear(unit, "VfxBlueGlow")

	func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
		return value + stacked if which == effect.stat else value


## HIT: the gain, once the attack lands (if the unit is still around).
class GainHit extends HitEffect:
	var tracker: Tracker
	var unit   # untyped: may be freed before a shot lands

	func _init(p_tracker: Tracker, p_unit: BattleUnit) -> void:
		tracker = p_tracker
		unit = p_unit

	func apply(_target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if is_instance_valid(unit) and unit.alive and tracker in unit.statuses:
			tracker._gain(unit)
