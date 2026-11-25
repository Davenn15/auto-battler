class_name Synthecyst
extends RefCounted
## The Synthecyst (Obelisk Ascension): the first summon an army makes becomes the Synthecyst
## instead, a slow melee brawler that absorbs a share of that summon's max health, attributes
## and Wards. While it lives, every later summon is absorbed into it instead of appearing. If
## it's dead when a summon happens, it Revives where the summon would have appeared, with the
## health it absorbs plus a share of its base health, keeping everything absorbed before.

const PROFILE := preload("res://data/units/obelisk/synthecyst/synthecyst.tres")
const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn
const COLOR := Color(0.55, 0.85, 0.5)
const STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY,
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]


## Called by BattleManager.add_summon for every summon before it joins. True if it took the
## summon (which is then gone): the caller must stop there.
static func intercept(manager: Node, summon: BattleUnit, ascensions: Array) -> bool:
	if summon.data == PROFILE or Revive.is_revived(summon):
		return false
	var effect: SynthecystEffect = null
	for ascension in ascensions:
		if ascension.effect is SynthecystEffect:
			effect = ascension.effect
	if effect == null:
		return false
	var key := "synthecyst_%d" % summon.team
	var record: Dictionary = manager.get_meta(key, {})
	var health := summon.max_health * effect.absorb_share
	var stats := {}
	for stat in STATS:
		stats[stat] = summon.base_stats.get(stat, 0.0) * effect.absorb_share
	var cell := summon.cell
	var parent := summon.get_parent()
	var credit := summon.get_summoner_id()
	_remove(summon)

	var cyst = instance_from_id(record.get("id", 0)) if record.has("id") else null
	if is_instance_valid(cyst) and cyst is BattleUnit and cyst.alive:
		_absorb(cyst, health, stats, record)
		manager.set_meta(key, record)
		return true

	# Made for the first time, or Revived.
	var reviving := record.has("id")
	var made := UNIT_SCENE.instantiate() as BattleUnit
	made.data = PROFILE
	made.team = summon.team
	made.auto_place = false
	made.is_summon = true
	made._summoner_id = credit
	parent.add_child(made)
	made.place_at(cell)
	if reviving:
		Revive.mark(made)
	manager.add_summon(made)
	if not is_instance_valid(made) or made.is_queued_for_deletion():
		return true
	made.add_status(SynthLookStatus.new())
	record["id"] = made.get_instance_id()
	var old_health: float = record.get("health", 0.0)
	var old_stats: Dictionary = record.get("stats", {})
	record["health"] = 0.0
	record["stats"] = {}
	_absorb(made, old_health, old_stats, record)   # what it held before it died
	_absorb(made, health, stats, record)
	if reviving:
		Revive.start(made, health + PROFILE.max_health * effect.revive_base_share)
		made.show_float_text("Synthecyst Revives", COLOR)
	else:
		made.set_health(made.max_health)
		made.show_float_text("Synthecyst", COLOR)
	manager.set_meta(key, record)
	return true


## Adds `health` max health (healing as much) and `stats` to the Synthecyst, and keeps the
## running totals in `record`.
static func _absorb(cyst: BattleUnit, health: float, stats: Dictionary, record: Dictionary) -> void:
	if health > 0.0:
		cyst.resize_health(cyst.max_health + health, cyst.health + health)
	var mass: MassStatus = null
	for status in cyst.statuses:
		if status is MassStatus:
			mass = status
	if mass == null:
		mass = MassStatus.new()
		cyst.add_status(mass)
	for stat in stats:
		mass.bonus[stat] = mass.bonus.get(stat, 0.0) + stats[stat]
	record["health"] = record.get("health", 0.0) + health
	var totals: Dictionary = record.get("stats", {})
	for stat in stats:
		totals[stat] = totals.get(stat, 0.0) + stats[stat]
	record["stats"] = totals
	if health > 0.0 or not stats.is_empty():
		KeepsakeVfx.flourish(cyst, COLOR)


## Takes a summon off the board before it ever joins the fight.
static func _remove(summon: BattleUnit) -> void:
	summon.remove_from_group("units")
	if summon.grid != null:
		summon.grid.vacate_all(summon)
	summon.visible = false
	summon.queue_free()


## The stats the Synthecyst has absorbed.
class MassStatus extends Status:
	var bonus: Dictionary = {}

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + bonus.get(stat, 0.0)


## A placeholder look, drawn in code (no art yet): a pulsing green cyst with dark veins,
## swelling with its max health.
class SynthLookStatus extends Status:
	var _look: Node2D

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		if not KeepsakeVfx.enabled():
			return
		if unit.sprite != null:
			unit.sprite.visible = false
		_look = CystLook.new()
		_look.unit = unit
		_look.z_index = 1
		unit.add_child(_look)

	func on_removed(_unit: BattleUnit) -> void:
		if is_instance_valid(_look):
			_look.queue_free()


class CystLook extends Node2D:
	var unit   # untyped: may be freed
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var grow := 1.0
		if is_instance_valid(unit):
			grow = clampf(sqrt(unit.max_health / Synthecyst.PROFILE.max_health), 1.0, 1.6)
		var pulse := 1.0 + sin(_time * 2.2) * 0.05
		var r := 15.0 * grow * pulse
		draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, r * 0.9, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.1, 0.95))
		draw_circle(Vector2.ZERO, r, Color(0.32, 0.55, 0.3))
		draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.55, Color(0.5, 0.8, 0.45))
		for i in 4:
			var a := TAU * i / 4.0 + 0.4
			var p := Vector2(cos(a), sin(a))
			draw_line(p * r * 0.2, p * r * 0.95 + p.orthogonal() * 3.0, Color(0.42, 0.18, 0.45, 0.85), 2.0)
		draw_circle(Vector2(r * 0.15, -r * 0.1), r * 0.18, Color(0.85, 0.95, 0.55))
		draw_set_transform(Vector2.ZERO)
