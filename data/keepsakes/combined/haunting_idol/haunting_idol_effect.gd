class_name HauntingIdolEffect
extends Passive
## Haunting Idol: whenever the unit debuffs or crowd-controls an enemy (anything that can
## Wrack as control, see BattleUnit.wrack_effect_multiplier), roll its Wrack Chance: on a
## success that enemy takes Damage Share of its max health, as the unit's attack damage
## type. Each enemy at most once per Cooldown seconds.
##   Might Ward Empower: the unit's debuffs and crowd control last Control Power longer.

@export_range(0.0, 1.0, 0.01) var damage_share: float = 0.08
@export var cooldown: float = 3.0
@export var control_power: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Haunt.new(self))


class Haunt extends Status:
	var effect: HauntingIdolEffect
	var _time := 0.0
	var _ready_at := {}   # enemy instance id -> time it can be haunted again
	var _haunting := false   # true while dealing the damage, so it can't set itself off

	func _init(p_effect: HauntingIdolEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(_unit: BattleUnit, delta: float) -> void:
		_time += delta

	func modify_control_power(_unit: BattleUnit, multiplier: float) -> float:
		return multiplier * (1.0 + effect.control_power)

	func on_control_applied(unit: BattleUnit, target: BattleUnit) -> void:
		if _haunting or not target.alive:
			return
		var id := target.get_instance_id()
		if _time < float(_ready_at.get(id, -1.0)):
			return
		if CombatRng.randf() >= unit.get_stat(Stats.Stat.WRACK_CHANCE):
			return
		_ready_at[id] = _time + effect.cooldown
		_haunting = true
		KeepsakeVfx.flourish(target, KeepsakeVfx.CONTROL_WRACK_COLOR)
		var amount := BattleUnit.damage_bonus(unit, target, target.max_health * effect.damage_share)
		var dealt := target.take_damage(amount, 0, unit.get_attack_damage_type(), false, null)
		unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
		_haunting = false
