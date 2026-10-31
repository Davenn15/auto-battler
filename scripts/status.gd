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

## Called when one of the unit's attacks lands, with the damage it dealt. For a ranged
## unit this is when the projectile arrives. Use for lifesteal and on-hit effects.
func on_attack_hit(_unit: BattleUnit, _target: BattleUnit, _dealt: float) -> void:
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

## Change the damage type of the unit's basic attacks.
func modify_attack_damage_type(_unit: BattleUnit, damage_type: int) -> int:
	return damage_type

## Adjust the unit's chance to completely avoid an incoming hit (0.1 = 10%).
func modify_dodge_chance(_unit: BattleUnit, chance: float) -> float:
	return chance

## Called as the unit makes an attack. Return a HitEffect to run when that attack lands,
## or null for nothing. Use this instead of on_attack_hit when the effect must still
## happen if this status ends while a projectile is in the air.
func get_hit_effect(_unit: BattleUnit) -> HitEffect:
	return null

## Called when one of the unit's attacks kills `victim`.
func on_kill(_unit: BattleUnit, _victim: BattleUnit) -> void:
	pass

## Adjust the size of a shield this unit is about to receive, from any source.
func modify_shield_received(_unit: BattleUnit, amount: float) -> float:
	return amount

## True makes the unit immune to crowd control (stuns now; slows, knockbacks later).
func blocks_crowd_control(_unit: BattleUnit) -> bool:
	return false

## Called when the unit dodges a hit.
func on_dodge(_unit: BattleUnit) -> void:
	pass
