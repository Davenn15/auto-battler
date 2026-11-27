class_name DelayedMendPassive
extends Passive
## M-Path's passive: Share x 100 percent Scar (see Scar), and he stores Store Share of the
## healing and regeneration he receives (extra, on top of what he gets; only what actually
## heals him counts). Every Send Interval seconds the store goes to the ally within Send
## Range cells with the lowest share of its health, as orbs that heal it when they land.
## With no ally to send to, it keeps the store for next time.

## Share of each hit that comes back (0.2 = 20% Scar).
@export_range(0.0, 1.0, 0.05) var share: float = 0.2
## Unused: Scar always comes back after Stats.SCAR_DELAY seconds. Kept so saved files load.
@export var delay: float = 3.0
## Share of the healing he receives that's stored (0.4 = 40%).
@export var store_share: float = 0.4
@export var send_interval: float = 3.0
@export var send_range: int = 3

const COLOR := Color(0.37, 0.82, 0.42)   # healing green


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(StatBonusStatus.new(Stats.Stat.SCAR, share * 100.0))
	unit.add_status(HealStoreStatus.new(self))


class HealStoreStatus extends Status:
	var passive: DelayedMendPassive
	var stored := 0.0
	var _timer := 0.0
	var _badge: StoreBadge = null

	func _init(p_passive: DelayedMendPassive) -> void:
		passive = p_passive
		_timer = p_passive.send_interval

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		if KeepsakeVfx.enabled():
			_badge = StoreBadge.new()
			_badge.position = Vector2(16, -22)
			_badge.z_index = 14
			unit.add_child(_badge)

	func on_removed(_unit: BattleUnit) -> void:
		if is_instance_valid(_badge):
			_badge.queue_free()

	## Stores a share of what actually heals him; his own healing is untouched.
	func modify_healing_received(unit: BattleUnit, amount: float) -> float:
		var landed := minf(maxf(amount, 0.0), maxf(unit.max_health - unit.health, 0.0))
		if landed > 0.0:
			stored += landed * passive.store_share
			_show()
		return amount

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		_timer -= delta
		if _timer > 0.0:
			return
		_timer += passive.send_interval
		if stored < 1.0:
			return
		var ally := _lowest_ally(unit)
		if ally == null:
			return
		HealOrb.send(unit, ally, stored)
		stored = 0.0
		_show()

	## The ally (not him) within Send Range with the lowest share of its health, or null.
	func _lowest_ally(unit: BattleUnit) -> BattleUnit:
		var best: BattleUnit = null
		for node in unit.get_tree().get_nodes_in_group("units"):
			var other := node as BattleUnit
			if other == null or other == unit or not other.alive or other.team != unit.team \
					or unit.grid.get_distance(unit.cell, other.cell) > passive.send_range:
				continue
			if best == null or other.health / other.max_health < best.health / best.max_health:
				best = other
		return best

	func _show() -> void:
		if is_instance_valid(_badge):
			_badge.amount = stored


## The store, by M-Path: a green orb with the amount beside it. Hidden while it's empty.
class StoreBadge extends Node2D:
	var amount := 0.0:
		set(value):
			amount = value
			queue_redraw()

	func _draw() -> void:
		if amount < 1.0:
			return
		draw_circle(Vector2.ZERO, 7.0, Color(DelayedMendPassive.COLOR, 0.35))
		draw_circle(Vector2.ZERO, 4.0, DelayedMendPassive.COLOR)
		var font := ThemeDB.fallback_font
		var text := str(roundi(amount))
		draw_string_outline(font, Vector2(9, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(9, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DelayedMendPassive.COLOR)


## The stored healing on its way: three green orbs arc from M-Path to the ally; the heal lands
## with the first (it still lands in sims, where nothing is drawn).
class HealOrb extends Node2D:
	const TIME := 0.45
	var from_id := 0
	var target   # untyped: may be freed
	var amount := 0.0
	var start := Vector2.ZERO
	var heals := false
	var _age := 0.0
	var delay := 0.0

	static func send(from: BattleUnit, to: BattleUnit, p_amount: float) -> void:
		for i in 3:
			var orb := HealOrb.new()
			orb.from_id = from.get_instance_id()
			orb.target = to
			orb.amount = p_amount
			orb.heals = i == 0
			orb.delay = i * 0.08
			orb.start = from.global_position + Vector2(0, -14)
			orb.z_index = 14
			orb.visible = KeepsakeVfx.enabled()
			from.get_tree().current_scene.add_child(orb)
			orb.global_position = orb.start

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(target) or not target.alive:
			queue_free()
			return
		if delay > 0.0:
			delay -= delta
			return
		_age += delta
		var t := minf(_age / TIME, 1.0)
		var goal: Vector2 = target.global_position + Vector2(0, -10)
		global_position = start.lerp(goal, t) + Vector2(0, -40.0 * sin(PI * t))
		queue_redraw()
		if t >= 1.0:
			if heals:
				target.heal(amount, from_id, true)
			queue_free()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 6.0, Color(DelayedMendPassive.COLOR, 0.35))
		draw_circle(Vector2.ZERO, 3.5, DelayedMendPassive.COLOR)
