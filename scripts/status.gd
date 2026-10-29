class_name Status
extends RefCounted
## Base class for effects that sit on a unit and react to what it does.
## Actions create these at runtime and attach them with unit.add_status().
## Override only the hooks you need. A status ends by calling unit.remove_status(self).

## Set automatically by the unit when an Action attaches this status.
var from_gambit: bool = false

## Called once when the status is attached to the unit.
func on_applied(_unit: BattleUnit) -> void:
	pass

## Called once when the status is removed (including when a battle starts or ends).
func on_removed(_unit: BattleUnit) -> void:
	pass

## Called every physics frame while attached. Use for timed effects.
func tick(_unit: BattleUnit, _delta: float) -> void:
	pass

## Adjust the damage of the unit's own attacks, before wrack is rolled.
func modify_outgoing_damage(_unit: BattleUnit, damage: float) -> float:
	return damage

## Called each time the unit makes an attack. Use for "next N attacks" effects.
func on_attack(_unit: BattleUnit) -> void:
	pass

## Adjust damage the unit is about to take (shields, damage reduction).
func modify_incoming_damage(_unit: BattleUnit, damage: float) -> float:
	return damage

## True stops the unit from gaining charge. By default, any status an Action
## created blocks charge until it ends. Override to change that for a specific status.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return from_gambit

## Change the color of projectiles the unit fires.
func modify_projectile_color(_unit: BattleUnit, color: Color) -> Color:
	return color

## Called when the unit Acts (at the moment its charge is spent).
func on_gambit(_unit: BattleUnit) -> void:
	pass

## Change the unit's time between attacks. Lower = faster.
func modify_attack_cooldown(_unit: BattleUnit, cooldown: float) -> float:
	return cooldown

## How much shield this status currently provides.
func get_shield(_unit: BattleUnit) -> float:
	return 0.0

func modify_health_regen(_unit: BattleUnit, regen: float) -> float:
	return regen

## Adjust one of the unit's stats. Items, powerups, and buffs will use this.
func modify_stat(_unit: BattleUnit, _stat: Stats.Stat, value: float) -> float:
	return value

## Adjust the chance that this unit's attack on `target` wracks.
func modify_wrack_chance(_unit: BattleUnit, _target: BattleUnit, chance: float) -> float:
	return chance
