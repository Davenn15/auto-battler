class_name FlexGambit
extends Gambit
## Brogaine: flexes for Duration seconds, gaining Regeneration equal to Regen Share of his
## max health per second and Ward Bonus to each Ward, but he can't attack meanwhile. When it ends he uppercuts his target (or, if it's out of reach,
## the next enemy in reach within Wait Time), dealing Damage + Might Scaling x Might,
## knocking it back Knockback Cells and stunning it.
##   A:  the first cast each combat gains him Glory.
##   A2: that first cast also grants Glory to the ally within Share Radius cells with the
##       least Glory that can still gain one this combat.

@export var duration: float = 3.0
## 0.06 = regenerates an extra 6% of his max health every second while flexing.
@export_range(0.0, 0.5, 0.005) var regen_share: float = 0.06
## Added to each of his Wards while he flexes.
@export var ward_bonus: float = 40.0
@export var damage: float = 120.0
@export var might_scaling: float = 0.8
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
@export var knockback_cells: int = 1
@export var stun_duration: float = 1.25
## Seconds after the flex he'll wait for an enemy to come into reach before giving up.
@export var wait_time: float = 3.0

@export_group("Glorious (A)")
## A: 1 = the first cast each combat gains him Glory.
@export var first_cast_glory: float = 0.0
## A2: 1 = the first cast also grants Glory to a nearby ally (see above).
@export var share_glory: float = 0.0
@export var share_radius: int = 1

const KNOCK_TIME := 0.2


func can_use(caster: BattleUnit) -> bool:
	return caster._enemy_in_range() != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	caster.add_status(FlexStatus.new(self))
	caster.show_float_text("Flex!", BrogaineFx.COLOR)
	BrogaineFx.flex(caster)
	if first_cast_glory > 0.0 and not caster.statuses.any(func(s): return s is FirstCastMark):
		caster.add_status(FirstCastMark.new())
		caster.gain_glory()
		if share_glory > 0.0:
			var ally := _least_glory_ally(caster)
			if ally != null:
				ally.gain_glory()


## The ally within Share Radius with the least Glory that can still gain one this combat.
## Ties go to the lowest instance id, so it never depends on the tree's order.
func _least_glory_ally(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for ally in HeartyAuraPassive.allies_near(caster, share_radius):
		if ally.glory_gained >= ally.glory_cap():
			continue
		var total := ally.glory + ally.glory_gained
		if best == null or total < best.glory + best.glory_gained \
				or (total == best.glory + best.glory_gained and ally.get_instance_id() < best.get_instance_id()):
			best = ally
	return best


## The uppercut on `target`: the hit, then the knockback, then the stun.
func uppercut(caster: BattleUnit, target: BattleUnit) -> void:
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	BrogaineFx.uppercut(caster, target)
	var dealt := target.take_damage(BattleUnit.damage_bonus(caster, target, hit), wrack, damage_type)
	BattleUnit.gambit_damage_dealt(caster, target, dealt)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
	if not target.alive:
		return
	var dest := knockback_destination(caster, target, knockback_cells)
	if dest != target.cell:
		target.lock_for(KNOCK_TIME)
		await target.force_move(dest, KNOCK_TIME)
	if is_instance_valid(target) and target.alive and is_instance_valid(caster):
		target.stun(stun_duration, caster)


## Where a knockback leaves `target`: up to `cells` steps away from `from`, each into the
## free neighbouring cell farthest from it (it must be farther than the last), the one
## straightest along the push when two tie. Stops early when the way is blocked. Units
## immune to crowd control, or that can't move, stay put.
static func knockback_destination(from: BattleUnit, target: BattleUnit, cells: int) -> Vector2i:
	if target.is_cc_immune() or target.is_immobile():
		return target.cell
	var grid := from.grid
	var push := (target.global_position - from.global_position).normalized()
	var at := target.cell
	for i in cells:
		var best := at
		var best_distance := grid.get_distance(at, from.cell)
		var best_align := -INF
		for offset in BladehookGambit.HEX_NEIGHBOURS:
			var next: Vector2i = at + offset
			if not grid.can_place(next):
				continue
			var distance := grid.get_distance(next, from.cell)
			if distance <= grid.get_distance(at, from.cell):
				continue
			var align := (grid.cell_to_world(next) - grid.cell_to_world(at)).normalized().dot(push)
			if distance > best_distance or (distance == best_distance and align > best_align):
				best = next
				best_distance = distance
				best_align = align
		if best == at:
			break
		at = best
	return at


## The flex, then the uppercut once it's over. A Gambit status, so he gains no Charge
## until the uppercut has landed (or he gave up waiting for someone to hit).
class FlexStatus extends Status:
	var gambit: FlexGambit
	var _time := 0.0

	func _init(p_gambit: FlexGambit) -> void:
		gambit = p_gambit

	func _flexing() -> bool:
		return _time < gambit.duration

	func modify_health_regen(unit: BattleUnit, regen: float) -> float:
		return regen + unit.max_health * gambit.regen_share if _flexing() else regen

	func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
		if _flexing() and (which == Stats.Stat.MIGHT_WARD or which == Stats.Stat.INSIGHT_WARD or which == Stats.Stat.CELERITY_WARD):
			return value + gambit.ward_bonus
		return value

	## No attacking while he flexes.
	func blocks_attacks(_unit: BattleUnit) -> bool:
		return _flexing()

	func tick(unit: BattleUnit, delta: float) -> void:
		_time += delta
		if _flexing():
			unit._attack_timer = maxf(unit._attack_timer, 0.5)   # the attack waits out the flex
			return
		if not unit.active:
			return
		if _time > gambit.duration + gambit.wait_time:
			unit.remove_status(self)   # nobody came into reach
			return
		if unit._stunned_time > 0.0:
			return   # can't swing while stunned; tries again once it wears off
		var target := unit.target if unit._is_valid_target(unit.target) \
				and unit.grid.get_distance(unit.cell, unit.target.cell) <= unit.attack_range else unit._enemy_in_range()
		if target == null:
			return
		unit.remove_status(self)
		gambit.uppercut(unit, target)


## Marks that the first cast this combat has happened (A). Lasts all combat.
class FirstCastMark extends Status:
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false
