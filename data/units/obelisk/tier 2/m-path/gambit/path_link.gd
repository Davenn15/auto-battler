class_name PathLink
extends Node2D
## A running link between M-PATH and an ally (see LinkGambit). Both get a LinkStatus that
## points back here. Ends when time runs out or either of them dies. Draws a pulsing line
## between them.

const COLOR := Color(1.0, 0.45, 0.75)

var source: BattleUnit   # M-PATH
var ally: BattleUnit
var time_left: float
var ward_bonus: float
var insight_bonus: float
var damage_share: float
var heal_share: float
var sacrifice_heal: float
## True while the link is passing damage or healing across, so it isn't passed straight back.
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


## A2: the ally would die. M-PATH dies in its place and heals it.
func sacrifice() -> void:
	if not _alive(source) or not _alive(ally):
		return
	var amount := source.max_health * sacrifice_heal
	ally.show_float_text("Sacrifice", COLOR)
	source.kill()
	ally.heal(amount, source.get_instance_id())


static func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


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


## On each linked unit: more wards (and A1's Insight), a share of its damage passed to its
## partner, and (Bonded) a share of its healing passed on too.
class LinkStatus extends Status:
	var link: PathLink
	var partner: BattleUnit

	func _init(p_link: PathLink, p_partner: BattleUnit) -> void:
		link = p_link
		partner = p_partner

	## Being linked never stops either of them gaining Charge.
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		match stat:
			Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD:
				return value + link.ward_bonus
			Stats.Stat.INSIGHT:
				return value + link.insight_bonus
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
		# A2: the ally would die, so M-PATH dies instead.
		if unit == link.ally and link.sacrifice_heal > 0.0 and amount >= unit.health \
				and is_instance_valid(link.source) and link.source.alive:
			amount = maxf(unit.health - 1.0, 0.0)
			link.sacrifice()   # heals it before this hit lands, so it ends above 1 health
		return amount

	func modify_healing_received(_unit: BattleUnit, amount: float) -> float:
		if is_instance_valid(link) and link.is_live() and not link.passing and link.heal_share > 0.0 and amount > 0.0:
			link.passing = true
			partner.heal(amount * link.heal_share, link.source.get_instance_id(), false)
			link.passing = false
		return amount
