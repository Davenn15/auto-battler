class_name Bleed
extends RefCounted
## The Bleed keyword (Sword Court's): "Bleed X" adds X damage to the target's Bleed pool.
## Every TICK_TIME seconds the pool deals DRAIN_SHARE of what's left (at least DRAIN_FLOOR,
## so the tail clears) in one hit of Pure Damage, so Wards never reduce it; the blood-drop
## counter pulses as it lands. The first tick comes TICK_TIME after a pool starts. Shields and other
## effects still apply. A unit is "Bleeding" while its pool has anything in it.
##
## Every unit that added to a pool is credited (damage meter, its damage bonuses) for its
## share of each tick. Damage bonuses apply when the Bleed is added. The pool shows on the
## health bar as damage still to come.

const TICK_TIME := 1.0       # seconds between Bleed's hits
const DRAIN_SHARE := 0.25    # of the pool, per tick
const DRAIN_FLOOR := 10.0    # damage per tick, at least
const COLOR := Color(0.78, 0.12, 0.14)   # the keyword's colour


## Adds `amount` Bleed to `target`'s pool, credited to `source` (a BattleUnit or its
## instance id; 0 for none). Damage bonuses `source` has against the target apply here.
## `with_bonus` off: the amount already includes the source's damage bonuses (Bleed worked
## out from damage dealt, like Cerceval's).
static func apply(target: BattleUnit, amount: float, source, with_bonus: bool = true) -> void:
	if not is_instance_valid(target) or not target.alive or target.previewing or amount <= 0.0:
		return
	var source_id: int = source if source is int else (source.get_instance_id() if is_instance_valid(source) else 0)
	if with_bonus:
		amount = BattleUnit.damage_bonus(source_id, target, amount)
	if amount <= 0.0:
		return
	var pool := pool_of(target)
	if pool == null:
		pool = Pool.new()
		target.add_status(pool)
	pool.add(amount, source_id)


## The Bleed left in `unit`'s pool (0 if none).
static func amount_on(unit: BattleUnit) -> float:
	var pool := pool_of(unit)
	return pool.total if pool != null else 0.0


## Deals all the Bleed left in `unit`'s pool at once (Cerceval B2). Returns how much.
static func burst(unit: BattleUnit) -> float:
	var pool := pool_of(unit)
	if pool == null or pool.total <= 0.0:
		return 0.0
	var amount := pool.total
	pool.burst(unit)
	return amount


## True while `unit` has Bleed in its pool.
static func is_bleeding(unit: BattleUnit) -> bool:
	return amount_on(unit) > 0.0


static func pool_of(unit: BattleUnit) -> Pool:
	if not is_instance_valid(unit):
		return null
	for status in unit.statuses:
		if status is Pool:
			return status
	return null


## Tells every enemy of `victim` with a status that cares (Status.on_enemy_bleed) that it
## just took `dealt` Bleed damage.
static func _tell_enemies(victim: BattleUnit, dealt: float) -> void:
	if not victim.is_inside_tree():
		return
	for node in victim.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit.team == victim.team or not unit.alive:
			continue
		for status in unit._with(&"on_enemy_bleed"):
			status.on_enemy_bleed(unit, victim, dealt)


## A Hit Effect that adds Bleed: a flat amount, plus a share of the target's max health.
class BleedHit extends HitEffect:
	var source_id: int
	var flat: float
	var max_health_share: float

	func _init(p_source_id: int, p_flat: float, p_max_health_share: float = 0.0) -> void:
		source_id = p_source_id
		flat = p_flat
		max_health_share = p_max_health_share

	func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if target.alive:   # the hit may have killed it
			Bleed.apply(target, flat + max_health_share * target.max_health, source_id)


## A unit's Bleed pool: one per unit, holding how much each source added.
class Pool extends Status:
	var total := 0.0
	var _by_source := {}   # source instance id -> Bleed of theirs still in the pool
	var _carrier   # untyped: the unit it's on, for the blood-drop counter
	var _until_tick := Bleed.TICK_TIME

	func on_applied(unit: BattleUnit) -> void:
		_carrier = unit

	func on_removed(unit: BattleUnit) -> void:
		KeepsakeVfx.bleed_badge(unit, 0.0)

	func add(amount: float, source_id: int) -> void:
		total += amount
		_by_source[source_id] = _by_source.get(source_id, 0.0) + amount
		if is_instance_valid(_carrier):
			KeepsakeVfx.bleed_badge(_carrier, total, true)   # with a bounce: Bleed just added

	## Someone else's debuff: never stops the carrier gaining Charge.
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func get_pending_damage(_unit: BattleUnit) -> float:
		return total

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active or not unit.alive or total <= 0.0:
			_until_tick = Bleed.TICK_TIME   # an empty pool restarts the clock when refilled
			return
		_until_tick -= delta
		if _until_tick > 0.0:
			return
		_until_tick += Bleed.TICK_TIME
		_deal(unit, minf(maxf(total * Bleed.DRAIN_SHARE, Bleed.DRAIN_FLOOR), total), false)


	## Deals everything left in the pool at once (Cerceval B2), as one hit with its own
	## damage number.
	func burst(unit: BattleUnit) -> void:
		if total > 0.0 and unit.alive:
			_deal(unit, total, true)


	## Deals `step` of the pool as Pure Damage, each source credited for its share.
	## `as_hit`: a burst, shown as its own damage number rather than the running Bleed one.
	func _deal(unit: BattleUnit, step: float, as_hit: bool) -> void:
		var share := step / total
		var dealt_total := 0.0
		for source_id in _by_source.keys():
			var part: float = _by_source[source_id] * share
			var dealt := 0.0
			if unit.alive:
				# Dealt before it leaves the pool, so a unit killed by its last Bleed still
				# counts as Bleeding when it dies (Codger B1's Glory).
				dealt = unit.take_warded_damage(part, as_hit, Stats.DamageType.PURE)
			_by_source[source_id] -= part
			total -= part
			if dealt <= 0.0:
				continue
			dealt_total += dealt
			if not as_hit:
				unit.add_running_damage("bleed", dealt, Bleed.COLOR)
			if source_id != 0:
				unit.get_tree().call_group("damage_tracker", "record_damage", source_id, dealt)
		if total <= 0.001:
			total = 0.0
			_by_source.clear()
		KeepsakeVfx.bleed_badge(unit, total, true)   # pulses with the hit
		if dealt_total > 0.0:
			Bleed._tell_enemies(unit, dealt_total)
