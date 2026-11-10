class_name MonoVirusStatus
extends Status
## Mono-Virus, used across the Obelisk faction. A debuff that lasts the rest of combat:
## each stack deals a share of the carrier's max health every second, and stacks have no
## limit. When the carrier dies, its stacks jump to its nearest living ally.
## Give stacks with MonoVirusStatus.infect(); never add this status directly.

## Its numbers (damage, wards, jumping, colour) are in mono_virus.tres, next to this script.
const SETTINGS: MonoVirusSettings = preload("res://data/units/obelisk/mono_virus/mono_virus.tres")
const GLOW_KEY := "VfxMonoVirus"
const BADGE_KEY := "VfxMonoVirusCount"

var stacks := 0
## Who the damage meter credits: whoever infected the carrier last.
var credit_id := 0
var _pending := 0.0   # damage not yet shown as a number
var _number_left := SETTINGS.number_interval


## Gives `target` `amount` more stacks, credited to `credit` (an instance id).
static func infect(target: BattleUnit, amount: int, credit: int) -> void:
	if target == null or not target.alive or amount <= 0:
		return
	var virus := of(target)
	if virus == null:
		virus = MonoVirusStatus.new()
		target.add_status(virus)
	virus.stacks += amount
	virus.credit_id = credit
	virus._update_glow(target)


## How many stacks `unit` carries (0 if none).
static func stacks_on(unit: BattleUnit) -> int:
	var virus := of(unit)
	return virus.stacks if virus != null else 0


static func of(unit: BattleUnit) -> MonoVirusStatus:
	if unit == null:
		return null
	for status in unit.statuses:
		if status is MonoVirusStatus:
			return status
	return null


func on_applied(unit: BattleUnit) -> void:
	unit.died.connect(_on_carrier_died)


func on_removed(unit: BattleUnit) -> void:
	if unit.died.is_connected(_on_carrier_died):
		unit.died.disconnect(_on_carrier_died)
	KeepsakeVfx.clear(unit, GLOW_KEY)
	KeepsakeVfx.clear(unit, BADGE_KEY)


## A debuff someone else gave: it never stops the carrier gaining Charge.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active or not unit.alive or stacks <= 0:
		return
	var amount := unit.max_health * SETTINGS.damage_per_stack * stacks * delta
	if not SETTINGS.ignore_wards:
		amount *= Stats.ward_multiplier(unit.get_stat(Stats.ward_stat_for(SETTINGS.damage_type)))
	var dealt := unit.take_warded_damage(amount, false, SETTINGS.damage_type)
	unit.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
	_pending += dealt
	_number_left -= delta
	if _number_left <= 0.0:
		_number_left += SETTINGS.number_interval
		if unit.alive and _pending > 0.0:
			unit._spawn_damage_number(_pending, SETTINGS.color)
		_pending = 0.0


## The carrier died: its stacks (or a share of them) jump to its nearest living ally.
func _on_carrier_died(dead: BattleUnit) -> void:
	if not SETTINGS.transfers_on_death or stacks <= 0:
		return
	var heir := _nearest_ally(dead)
	if heir == null:
		return
	KeepsakeVfx.virus_jump(dead.global_position, heir)
	infect(heir, maxi(floori(stacks * SETTINGS.transfer_share), 1), credit_id)


func _nearest_ally(dead: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	var best_distance := INF
	for node in dead.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == dead or not unit.alive or unit.team != dead.team:
			continue
		var distance := dead.global_position.distance_squared_to(unit.global_position)
		if distance < best_distance:
			best_distance = distance
			best = unit
	return best


func _update_glow(unit: BattleUnit) -> void:
	KeepsakeVfx.set_glow(unit, GLOW_KEY, SETTINGS.color, KeepsakeVfx.stack_strength(stacks))
	KeepsakeVfx.virus_badge(unit, BADGE_KEY, stacks)
