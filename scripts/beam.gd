class_name Beam
extends RefCounted
## The official "Beam" keyword (used by Obelisk units): a continuous, targeted beam. These
## are Beams:
##   - Scour's attack, BEAM.NG's attack and MOTHER-CHIP's B attack (and her Chips' beams),
##     all built on BeamStatus;
##   - COLUMN's two beam weapons (ColumnBeamWeapon);
##   - BEAM.NG's Focus Beam (FocusBeamGambit) and Shield Beam (ShieldBeamGambit).
##
## Every Beam reads its Settings each frame, so effects (an Ascension's effect, say) can
## change all Beams at once: give the unit a Status whose modify_beam() adjusts them. The
## Settings say which kind of Beam is asking, so an effect can pick only some.
## New Beams should read Settings too, and use ricochet_targets() for extra ricochets.

enum Kind { ATTACK, WEAPON, FOCUS, SHIELD }

## Every Beam's rhythm. A Beam ticks TICKS_PER_ATTACK times per attack interval (its unit's,
## or a COLUMN weapon's own), each tick dealing or shielding its share all at once: so it
## delivers exactly as much per second as before, and Celerity makes the ticks come faster.
## After switching to a new target it charges up for RETARGET_SHARE of an attack interval
## first (also faster with Celerity). Each tick sends a bright pulse down the beam.
const TICKS_PER_ATTACK := 4
const RETARGET_SHARE := 1.0 / 3.0

## True while an attack Beam runs its once-per-attack effects (its on_attack calls), so an
## effect that counts Beam ticks itself (FRAME's Compassing) can skip those.
static var flushing := false

## An attack Beam tick landed on `enemy`: tells every Status on the unit (on_beam_tick).
static func notify_tick(unit: BattleUnit, enemy: BattleUnit) -> void:
	for status in unit.statuses.duplicate():
		status.on_beam_tick(unit, enemy)

## True if any of the unit's attacks are Beams.
static func has_attack_beam(unit: BattleUnit) -> bool:
	for status in unit.statuses:
		if status.is_attack_beam():
			return true
	return false

## Seconds a tick's pulse takes to travel down the beam, and to flare where it lands.
const PULSE_TRAVEL := 0.16
const PULSE_FLARE := 0.14


## Seconds between ticks for a Beam whose attack interval is `attack_interval`.
static func tick_interval(attack_interval: float) -> float:
	return maxf(attack_interval / TICKS_PER_ATTACK, 0.02)


## The share of an attack (or of a second's shielding, see tick_interval) one tick delivers.
static func tick_share(beam: Settings) -> float:
	return beam.rate / TICKS_PER_ATTACK


## Seconds a Beam charges up after switching to a new target.
static func retarget_time(attack_interval: float) -> float:
	return attack_interval * RETARGET_SHARE


## What a unit's Beams are like right now. Every Beam starts from these defaults; Statuses
## change them in modify_beam().
class Settings extends RefCounted:
	var caster: BattleUnit
	## Which Beam is asking: an attack beam, a COLUMN weapon, Focus Beam or Shield Beam.
	var kind: Kind
	## Extra reach, in hex cells. (For attack beams this is added to the unit's attack range.)
	var range_bonus: int = 0
	## How fast the Beam delivers its damage or shielding: 1.3 = 30% more per second.
	var rate: float = 1.0
	## How fast a Beam's ramp builds up (Scour's damage and Wrack ramps): 2 = twice as fast.
	var ramp_speed: float = 1.0
	## How fast a Beam charges up after switching targets: 2 = half the delay.
	var charge_up_speed: float = 1.0
	## Extra targets the Beam ricochets to from its (last) target, on top of any it has.
	var extra_ricochets: int = 0
	## How effective those extra ricochets are: 0.5 = half the damage or shielding.
	var ricochet_share: float = 0.5
	## How close each extra ricochet target must be to the one before, in hex cells.
	var ricochet_range: int = 2

	func _init(p_caster: BattleUnit, p_kind: Kind) -> void:
		caster = p_caster
		kind = p_kind


## `unit`'s Beam settings for a Beam of `kind`, after every Status has had its say.
static func settings(unit: BattleUnit, kind: Kind) -> Settings:
	var result := Settings.new(unit, kind)
	if is_instance_valid(unit):
		for status in unit.statuses:
			status.modify_beam(unit, result)
	return result


## True if a unit of `data` on upgrade `path` has a Beam: its passives (its own and its
## upgrades') or its Gambit are one of the Beams above. MOTHER-CHIP only counts on her B
## path, BEAM.NG always (its attack). New kinds of Beam need adding here.
static func has_beam(data: UnitData, path: Array) -> bool:
	if data == null:
		return false
	var passives: Array = data.passives.duplicate()
	var gambits: Array = [data.gambit]
	var choices := data.upgrades
	for pick in path:
		if pick < 0 or pick >= choices.size():
			break
		passives.append_array(choices[pick].passives)
		gambits.append(choices[pick].gambit)
		choices = choices[pick].next_choices
	for passive in passives:
		if passive is BeamPassive or passive is BeamngPassive or passive is ColumnBeamWeapon or passive is MotherBeamPassive:
			return true
	for gambit in gambits:
		if gambit is FocusBeamGambit or gambit is ShieldBeamGambit:
			return true
	return false


## Up to `count` more targets for a Beam to ricochet to, each the nearest valid one within
## `range_cells` of the one before, starting from `from` and never one in `skip`. Enemies
## of `caster`, or (with `allies`) its lowest-health allies, as Shield Beam picks.
static func ricochet_targets(caster: BattleUnit, from: BattleUnit, count: int, range_cells: int,
		skip: Array, allies: bool = false) -> Array:
	var chain: Array = []
	var taken := skip.duplicate()
	var last := from
	for i in count:
		if not is_instance_valid(last):
			break
		var next: BattleUnit = BeamLinks.lowest_ally(caster, last, range_cells, taken) if allies \
				else BeamLinks.nearest_enemy(caster, last, range_cells, taken)
		if next == null:
			break
		chain.append(next)
		taken.append(next)
		last = next
	return chain


## The plain damage of one Beam tick at `share` of an attack (no Wrack, no ramp), for
## ricochets: the caster's attack damage after its damage buffs.
static func tick_damage(caster: BattleUnit, share: float) -> float:
	var base := Stats.attack_damage(caster.get_stat(Stats.Stat.MIGHT))
	for status in caster.statuses.duplicate():
		base = status.modify_outgoing_damage(caster, base)
	return base * share


## Deals one ricochet tick of `hit` damage to each of `targets`, as `caster`'s Beam:
## damage meter, running damage number. Returns the total dealt.
static func hit_ricochets(caster: BattleUnit, targets: Array, hit: float) -> float:
	var total := 0.0
	for target in targets:
		if not is_instance_valid(target) or not target.alive:
			continue
		var dealt: float = target.take_damage(hit, 0, caster.get_attack_damage_type(), caster.ignores_wards(), caster, false)
		caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
		target.add_running_damage("beam_%d" % caster.get_instance_id(), dealt, Stats.damage_color(caster.get_attack_damage_type()))
		total += dealt
	return total


## The lines of a Beam's extra ricochets on screen: from its target to each ricochet in turn.
class RicochetLines extends RefCounted:
	var _links: BeamLinks = null
	var _from = null   # untyped: may be freed

	## Draws `from` -> targets[0] -> targets[1] ..., or nothing when `targets` is empty.
	func show(from: BattleUnit, targets: Array, color: Color) -> void:
		if targets.is_empty() or not is_instance_valid(from):
			clear()
			return
		if _links == null or _from != from:
			clear()
			_links = BeamLinks.new(from)
			_from = from
		_links.show(targets, color)

	## A tick: a pulse down each ricochet line.
	func pulse() -> void:
		if _links != null:
			_links.pulse()

	func clear() -> void:
		if _links != null:
			_links.clear()
		_links = null
		_from = null
