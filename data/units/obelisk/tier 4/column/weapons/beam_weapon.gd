class_name ColumnBeamWeapon
extends ColumnWeapon
## A continuous lime beam at an enemy in range. Over one Interval it deals Damage Share of a
## normal attack, in short ticks that each roll Wrack. Things that happen once per attack
## (on-attack and on-hit effects, item hit effects, the damage number, the enemy's Charge
## from being hit) happen once per Interval's worth of beam, so items don't trigger every
## tick. COLUMN's two beams pick different enemies when they can: beam 2 avoids beam 1's
## target, and both fire at the same enemy only when it's the only one in range.

## Share of a normal attack's damage each Interval of beam deals.
@export var damage_share: float = 0.6
## Seconds the beam charges up after switching targets before it deals damage.
@export var retarget_delay: float = 0.3
## Which beam this is (0 = first). Later beams avoid earlier beams' targets.
@export var slot: int = 0


func make_status() -> Status:
	return BeamStatusColumn.new(self)


class BeamStatusColumn extends Status:
	const TICK := 0.1

	var weapon: ColumnBeamWeapon
	var target = null   # untyped: may be freed
	var _charging := 0.0
	var _tick_left := 0.0
	var _progress := 0.0
	var _dealt := 0.0
	var _best_wrack := 0
	var _visual: BeamStatus.BeamLine = null

	func _init(p_weapon: ColumnBeamWeapon) -> void:
		weapon = p_weapon

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_removed(_unit: BattleUnit) -> void:
		if is_instance_valid(_visual):
			_visual.queue_free()

	func tick(unit: BattleUnit, delta: float) -> void:
		if not ColumnWeapon.can_act(unit):
			_show(unit, null, false)
			return
		var enemy := _pick_target(unit)
		if enemy == null:
			_flush(unit)
			target = null
			_show(unit, null, false)
			return
		if enemy != target:
			_flush(unit)
			target = enemy
			_charging = weapon.retarget_delay
			_tick_left = 0.0
		if _charging > 0.0:
			_charging -= delta
			_show(unit, enemy, false)
			return
		_show(unit, enemy, true)
		_tick_left -= delta
		var cooldown := weapon.interval * ColumnWeapon.speed_scale(unit)
		while _tick_left <= 0.0 and is_instance_valid(enemy) and enemy.alive:
			_tick_left += TICK
			_fire_tick(unit, enemy, TICK / cooldown)

	## Keeps its target while it's still valid; otherwise the nearest enemy in range that an
	## earlier beam isn't firing at (or any, if that's the only one).
	func _pick_target(unit: BattleUnit) -> BattleUnit:
		var in_range := ColumnWeapon.enemies_in_range(unit, unit.attack_range)
		if in_range.is_empty():
			return null
		var taken := _taken_by_earlier_beams(unit)
		if is_instance_valid(target) and in_range.has(target) and (not taken.has(target) or in_range.size() == 1):
			return target
		for enemy in in_range:
			if not taken.has(enemy):
				return enemy
		return in_range[0]

	func _taken_by_earlier_beams(unit: BattleUnit) -> Array:
		var taken := []
		for status in unit.statuses:
			if status is BeamStatusColumn and status != self and status.weapon.slot < weapon.slot \
					and is_instance_valid(status.target):
				taken.append(status.target)
		return taken

	func _fire_tick(unit: BattleUnit, enemy: BattleUnit, share: float) -> void:
		var chance := unit.get_stat(Stats.Stat.WRACK_CHANCE)
		for status in unit.statuses:
			chance = status.modify_wrack_chance(unit, enemy, chance)
		var wrack_level := Stats.roll_wrack(chance)
		var base := Stats.attack_damage(unit.get_stat(Stats.Stat.MIGHT))
		for status in unit.statuses.duplicate():
			base = status.modify_outgoing_damage(unit, base)
		var hit := base * weapon.damage_share * share * Stats.wrack_multiplier(wrack_level, unit.get_wrack_damage_against(enemy))
		var dealt := enemy.take_damage(hit, wrack_level, unit.get_attack_damage_type(), unit.ignores_wards(), unit, false)
		unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
		enemy.add_running_damage("beam_%d" % get_instance_id(), dealt, Stats.damage_color(unit.get_attack_damage_type(), wrack_level), wrack_level)
		_dealt += dealt
		_best_wrack = maxi(_best_wrack, wrack_level)
		_progress += share
		if _progress >= 1.0 or not enemy.alive:
			_flush(unit)

	## One attack's worth of beam has landed: the once-per-attack effects.
	func _flush(unit: BattleUnit) -> void:
		if _progress <= 0.0:
			return
		var enemy = target
		var dealt := _dealt
		var wrack := _best_wrack
		_progress = 0.0
		_dealt = 0.0
		_best_wrack = 0
		var effects: Array[HitEffect] = []
		for status in unit.statuses.duplicate():
			var effect: HitEffect = status.get_hit_effect(unit)
			if effect != null:
				effects.append(effect)
			status.on_attack(unit)
		if not is_instance_valid(enemy):
			return
		if dealt > 0.0:
			enemy.gain_charge_from_hit(dealt)
		enemy.notify_attacked(unit, dealt)
		unit.notify_attack_hit(enemy, dealt)
		BattleUnit.run_hit_effects(effects, enemy, dealt, wrack)

	func _show(unit: BattleUnit, enemy, firing: bool) -> void:
		ColumnBeamWeapon.show_beam(self, unit, enemy, firing, ColumnWeapon.COLOR)


## Draws a beam for `holder` (any object with a `_visual` BeamLine field) from COLUMN to
## `to_unit`, or hides it when that's null.
static func show_beam(holder, unit: BattleUnit, to_unit, firing: bool, color: Color) -> void:
	if not KeepsakeVfx.enabled():
		return
	if to_unit == null:
		if is_instance_valid(holder._visual):
			holder._visual.visible = false
		return
	if not is_instance_valid(holder._visual):
		holder._visual = BeamStatus.BeamLine.new()
		holder._visual.owner_unit = unit
		holder._visual.z_index = 9
		unit.get_tree().current_scene.add_child(holder._visual)
	holder._visual.visible = true
	holder._visual.target = to_unit
	holder._visual.firing = firing
	holder._visual.color = color
