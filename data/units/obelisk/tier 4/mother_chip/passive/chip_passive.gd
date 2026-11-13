class_name ChipPassive
extends Passive
## MOTHER-CHIP's passive. Her attacks give a stack of Mono-Virus, and she's orbited by
## Chips: untargetable drones that shoot her target every time she attacks, each for Chip
## Share of her attack. With her B path (MotherBeamPassive) her attacks are a beam, and the
## Chips beam her target alongside her instead (see MotherBeamStatus).

const COLOR := Color(0.45, 0.42, 1.0)   # bluish purple
const LIGHT := Color(0.72, 0.7, 1.0)

@export var chips: int = 2
## Share of her attack damage each Chip's shot deals (0.25 = 25%).
@export_range(0.0, 2.0, 0.05) var chip_share: float = 0.25
## Mono-Virus stacks each of her attacks gives.
@export var virus_per_attack: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ChipStatus.new(self))


## MOTHER-CHIP's Chips, or null.
static func of(unit: BattleUnit) -> ChipStatus:
	if unit == null:
		return null
	for status in unit.statuses:
		if status is ChipStatus:
			return status
	return null


class ChipStatus extends Status:
	var passive: ChipPassive
	var chips: int
	## B2: a Chip for every ally that dies (set by ChipBoostPassive).
	var chip_per_ally_death := false
	var _holder   # untyped: may be freed
	var _watching: Dictionary = {}
	var _recheck := 0.0
	var _orbit: ChipOrbit
	var _time := 0.0

	func _init(p_passive: ChipPassive) -> void:
		passive = p_passive
		chips = p_passive.chips

	func on_applied(unit: BattleUnit) -> void:
		_holder = unit
		if KeepsakeVfx.enabled():
			_orbit = ChipOrbit.new()
			_orbit.status = self
			_orbit.z_index = 12
			unit.add_child(_orbit)

	func on_removed(_unit: BattleUnit) -> void:
		if is_instance_valid(_orbit):
			_orbit.queue_free()

	func add_chips(amount: int) -> void:
		chips += maxi(amount, 0)

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return VirusHit.new(passive.virus_per_attack, unit.get_credit_id())

	## Her attack landed: every Chip shoots the same target (only when she fires shots;
	## her B beam handles the Chips itself).
	func on_attack_hit(unit: BattleUnit, target: BattleUnit, _dealt: float) -> void:
		if MotherBeamStatus.of(unit) != null or not is_instance_valid(target) or not target.alive:
			return
		var amount := Stats.attack_damage(unit.get_stat(Stats.Stat.MIGHT)) * passive.chip_share
		for i in chips:
			var shot := Projectile.new()
			shot.is_attack = false
			shot.setup(unit, target, amount, ChipPassive.LIGHT, 0, unit.get_attack_damage_type())
			shot.scale = Vector2(0.45, 0.45)
			unit.get_parent().add_child(shot)
			shot.global_position = unit.global_position + chip_offset(i, unit)

	## Where Chip `i` is, relative to MOTHER-CHIP: rings of orbiting Chips, more rings as
	## she gains more.
	func chip_offset(i: int, unit: BattleUnit) -> Vector2:
		var time := _time   # battle time, so shots start from the same spot on every machine
		var ring := floori(i / 6.0)
		var in_ring := mini(chips - ring * 6, 6)
		var radius := 22.0 + ring * 9.0
		var angle := TAU * (i % 6) / maxf(in_ring, 1.0) + time * (1.6 - ring * 0.3) * (1.0 if ring % 2 == 0 else -1.0)
		return Vector2(cos(angle) * radius, sin(angle) * radius * 0.55 - 14.0).rotated(unit.global_rotation)

	func tick(unit: BattleUnit, delta: float) -> void:
		_time += delta
		if not chip_per_ally_death or not unit.active:
			return
		_recheck -= delta
		if _recheck > 0.0:
			return
		_recheck = 0.25
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or ally == unit or not ally.alive or ally.team != unit.team:
				continue
			if not _watching.has(ally.get_instance_id()):
				_watching[ally.get_instance_id()] = true
				ally.died.connect(_on_ally_died)

	## B2: an ally died; its source code becomes another Chip.
	func _on_ally_died(ally: BattleUnit) -> void:
		if not is_instance_valid(_holder) or not _holder.alive or not _holder.active:
			return
		add_chips(1)
		if KeepsakeVfx.enabled():
			KeepsakeVfx.recycle_orb(ally.global_position, _holder)
			_holder.show_float_text("+1 Chip", ChipPassive.LIGHT)


## One stack of Mono-Virus per attack.
class VirusHit extends HitEffect:
	var stacks: int
	var credit_id: int

	func _init(p_stacks: int, p_credit_id: int) -> void:
		stacks = p_stacks
		credit_id = p_credit_id

	func apply(target: BattleUnit, dealt: float, _wrack_level: int) -> void:
		if dealt > 0.0 and target.alive:
			MonoVirusStatus.infect(target, stacks, credit_id)


## The Chips on screen: small glowing squares orbiting her, with a circuit trace on each.
## In beam mode, each Chip draws its own thin beam to her target while she fires.
class ChipOrbit extends Node2D:
	var status: ChipStatus

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if status == null:
			return
		var unit := get_parent() as BattleUnit
		if unit == null:
			return
		var beam := MotherBeamStatus.of(unit)
		var beam_target = beam.firing_at() if beam != null else null
		for i in status.chips:
			var at := (status.chip_offset(i, unit)).rotated(-unit.global_rotation)
			if beam_target != null:
				var to := to_local(beam_target.global_position)
				draw_line(at, to, Color(ChipPassive.COLOR, 0.35), 3.0, true)
				draw_line(at, to, Color(ChipPassive.LIGHT, 0.8), 1.0, true)
			draw_rect(Rect2(at - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.12, 0.1, 0.3))
			draw_rect(Rect2(at - Vector2(3.5, 3.5), Vector2(7, 7)), ChipPassive.LIGHT, false, 1.0)
			draw_line(at + Vector2(-2, 0), at + Vector2(2, 0), Color(ChipPassive.LIGHT, 0.8), 1.0)
