class_name PathLink
extends Node2D
## A running link between M-Path and an ally (see LinkGambit). Both get a LinkStatus that
## points back here. Ends when time runs out (never, for a permanent one) or either of them
## dies. Draws a pulsing line between them.

const COLOR := Color(1.0, 0.45, 0.75)

var source: BattleUnit   # M-Path
var ally: BattleUnit
var time_left: float
var regen_bonus: float
var ward_bonus: float      # all three Wards
var might_bonus: float     # A1
var vampirism_bonus: float # A1
var damage_share: float
var sacrifice_share: float # A2
## A: it never runs out (and doesn't hold back M-Path's Charge, so he can cast again).
var permanent := false
## True while the link is passing damage across, so it isn't passed straight back.
var passing := false
var _statuses: Array = []
var _time := 0.0


## Links `p_source` and `p_ally`. Call after setting the numbers above.
func start(p_source: BattleUnit, p_ally: BattleUnit) -> void:
	source = p_source
	ally = p_ally
	z_index = 9
	for pair in [[source, ally], [ally, source]]:
		var status := LinkStatus.new(self, pair[1])
		_statuses.append(status)
		pair[0].add_status(status)


func is_live() -> bool:
	return time_left > 0.0 and _alive(source) and _alive(ally)


func _physics_process(delta: float) -> void:
	time_left -= delta
	if not is_live():
		end()


## Ends the link and takes its statuses off both units.
func end() -> void:
	time_left = 0.0
	for unit in [source, ally]:
		if is_instance_valid(unit):
			for status in _statuses:
				unit.remove_status(status)
	_statuses.clear()
	queue_free()


## A2: the ally would die. M-Path gives up Sacrifice Share of his current health (never
## going below 1 health) and heals the ally for the same. Every time. Returns how much he gave.
func sacrifice() -> float:
	if not _alive(source) or not _alive(ally):
		return 0.0
	var amount := minf(source.health * sacrifice_share, source.health - 1.0)
	if amount <= 0.0:
		return 0.0
	source.set_health(source.health - amount)
	source.show_float_text("-%d" % roundi(amount), COLOR)
	ally.show_float_text("Sacrifice", COLOR)
	ally.heal(amount, source.get_instance_id(), true, true)
	return amount


static func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


## A's recast heal on `unit`: a green ring that swells and fades (the heal shows its number).
static func heal_ring(unit: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit):
		return
	var ring := HealRing.new()
	ring.radius = KeepsakeVfx._sprite_size(unit).length() * 0.42
	ring.z_index = 11
	unit.add_child(ring)


class HealRing extends Node2D:
	const LIFE := 0.6
	const GREEN := Color(0.37, 0.82, 0.42)
	var radius := 24.0
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / LIFE
		draw_arc(Vector2.ZERO, radius * (0.8 + 0.4 * t), 0.0, TAU, 40, Color(GREEN, 0.9 * (1.0 - t)), 3.0, true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not _alive(source) or not _alive(ally):
		return
	var from := to_local(source.global_position)
	var to := to_local(ally.global_position)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	draw_line(from, to, Color(COLOR, 0.15 + 0.1 * pulse), 9.0, true)
	draw_line(from, to, Color(COLOR, 0.75), 2.0, true)
	for i in 3:   # beads of light running both ways along the link
		var t := fmod(_time * 0.8 + i / 3.0, 1.0)
		draw_circle(from.lerp(to, t), 3.0, Color(1, 1, 1, 0.8))
		draw_circle(to.lerp(from, t), 2.5, Color(COLOR, 0.9))
	draw_arc(from, 14.0, 0.0, TAU, 24, Color(COLOR, 0.5 + 0.3 * pulse), 2.0, true)
	draw_arc(to, 14.0, 0.0, TAU, 24, Color(COLOR, 0.5 + 0.3 * pulse), 2.0, true)


## On each linked unit: more health regen, a share of its damage passed to its partner,
## and (A) more Might Ward and Celerity Ward, (A1) more Insight.
class LinkStatus extends Status:
	var link: PathLink
	var partner: BattleUnit

	func _init(p_link: PathLink, p_partner: BattleUnit) -> void:
		link = p_link
		partner = p_partner

	## M-Path gains no Charge while a timed link is up; the ally gains Charge as normal. A
	## permanent link (A) never holds his Charge back, so he can cast again to heal.
	func blocks_charge_gain(unit: BattleUnit) -> bool:
		return is_instance_valid(link) and unit == link.source and link.is_live() and not link.permanent

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if not is_instance_valid(link) or not link.is_live():
			return value
		match stat:
			Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD:
				return value + link.ward_bonus
			Stats.Stat.MIGHT:
				return value + link.might_bonus
			Stats.Stat.VAMPIRISM:
				return value + link.vampirism_bonus
		return value

	func modify_incoming_damage(unit: BattleUnit, amount: float) -> float:
		if not is_instance_valid(link) or not link.is_live() or amount <= 0.0:
			return amount
		if not link.passing and link.damage_share > 0.0:
			var passed := amount * link.damage_share
			link.passing = true
			partner.take_warded_damage(passed, false, unit.incoming_damage_type)
			link.passing = false
			amount -= passed
		# A2: the ally would die, so M-Path gives up health to save it.
		if unit == link.ally and link.sacrifice_share > 0.0 and amount >= unit.health:
			var survivable := maxf(unit.health - 1.0, 0.0)   # taken before the heal lands
			if link.sacrifice() > 0.0:
				amount = survivable   # the hit leaves it at 1 health, plus the heal
		return amount

	func modify_health_regen(_unit: BattleUnit, value: float) -> float:
		if is_instance_valid(link) and link.is_live():
			return value + link.regen_bonus
		return value
