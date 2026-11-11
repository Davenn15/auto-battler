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

## Damage this status is holding back, to be dealt later (like Bescard's passive).
## Shown on the health bar as health about to be lost.
func get_pending_damage(_unit: BattleUnit) -> float:
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

## Crowd control on this unit lasts multiplier times as long (0.65 = 35% shorter).
## MALLET's passive lowers it. Pass the value on, changed or not.
func modify_crowd_control(_unit: BattleUnit, multiplier: float) -> float:
	return multiplier

## How effective debuffs on this unit are (0.65 = 35% less): timed ones wear off that much
## sooner, ones that last all combat are that much weaker. MALLET's passive lowers it.
func modify_debuff_strength(_unit: BattleUnit, multiplier: float) -> float:
	return multiplier

## Called when the unit dodges a hit.
func on_dodge(_unit: BattleUnit) -> void:
	pass

## True makes the unit untargetable: enemies drop it as their target and can't pick it.
func blocks_targeting(_unit: BattleUnit) -> bool:
	return false

## Called when a projectile is about to hit the unit. Return true if this status sent it
## somewhere else (by calling projectile.reflect), so it doesn't hit.
func try_reflect(_unit: BattleUnit, _projectile: Projectile) -> bool:
	return false

## Lets a status change who the unit picks as its next target. `choice` is the nearest
## valid enemy (or null); `exclude` is an enemy it must not pick. Return the one to use.
func modify_target_choice(_unit: BattleUnit, choice: BattleUnit, _exclude: BattleUnit) -> BattleUnit:
	return choice

## Runs after every status's modify_stat, for effects that need the finished number,
## like turning one stat into another.
func modify_final_stat(_unit: BattleUnit, _stat: Stats.Stat, value: float) -> float:
	return value

## Lets a status replace the projectile the unit's ranged attacks fire. Return null to
## keep the normal one.
func create_projectile(_unit: BattleUnit) -> Projectile:
	return null

## Called on each of the unit's statuses when another status is added to it.
func on_status_added(_unit: BattleUnit, _added: Status) -> void:
	pass


## True for statuses that permanently raise the unit's stats for the rest of combat
## (Sumpton's blades, Von Carrow's Triggerhappy). Effects that react to "gaining
## permanent stats" check this.
func is_permanent_stat_gain() -> bool:
	return false

## Lets a status change the unit's wrack damage against a particular target, like
## modify_wrack_chance does for wrack chance.
func modify_wrack_damage(_unit: BattleUnit, _target: BattleUnit, value: float) -> float:
	return value

## True makes all of the unit's damage skip the target's wards.
func ignores_wards(_unit: BattleUnit) -> bool:
	return false

## True stops the unit from walking. It still attacks enemies already in range.
func blocks_movement(_unit: BattleUnit) -> bool:
	return false

## True stops the unit from casting its Gambit, even with full charge.
func blocks_gambit(_unit: BattleUnit) -> bool:
	return false

## The stats this status permanently adds, as {Stats.Stat: amount}. Empty for statuses
## that don't. Effects that copy permanent gains (Lordred) read this.
func get_permanent_stat_gains() -> Dictionary:
	return {}


## Called when an enemy's attack reaches the unit, hit or dodged. `dealt` is what it dealt
## (0 if dodged).
func on_attacked(_unit: BattleUnit, _attacker: BattleUnit, _dealt: float) -> void:
	pass

## Lets a status change healing the unit receives, before it's applied.
func modify_healing_received(_unit: BattleUnit, amount: float) -> float:
	return amount

## Lets a status change charge the unit is about to gain.
func modify_charge_gain(_unit: BattleUnit, amount: float) -> float:
	return amount

## On the attacker: changes the damage of a hit it deals to `target`, after wards.
func modify_damage_dealt(_unit: BattleUnit, _target: BattleUnit, amount: float) -> float:
	return amount


## On the attacker: changes the ward `target` uses against this hit.
func modify_target_ward(_unit: BattleUnit, _target: BattleUnit, ward: float, _wrack_level: int) -> float:
	return ward


## On the unit being hit: changes the charge its attacker gains for landing the hit.
func modify_attacker_charge(_unit: BattleUnit, _attacker: BattleUnit, amount: float) -> float:
	return amount


## Called after the unit actually gains charge, with how much it gained.
func on_charge_gained(_unit: BattleUnit, _amount: float) -> void:
	pass

## True lets this kind of effect from the unit wrack (Gambit damage, control and debuff
## effects, or heals and shields).
func lets_wrack(_unit: BattleUnit, _kind: Stats.EffectKind) -> bool:
	return false


## Extra wrack damage for Gambit damage that could already wrack on its own.
func gambit_wrack_bonus(_unit: BattleUnit) -> float:
	return 0.0


## The colour of the unit's melee sword swing. Purely visual.
func modify_swing_color(_unit: BattleUnit, color: Color) -> Color:
	return color
