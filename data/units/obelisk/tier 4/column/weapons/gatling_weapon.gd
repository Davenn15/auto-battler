class_name ColumnGatlingWeapon
extends ColumnWeapon
## B1: a gatling cannon that fires small shots at the nearest enemy in range. Each shot at
## the same enemy as the last comes faster, down to a minimum gap; switching enemies spins
## it back down. Gaps also shrink and grow with COLUMN's attack speed.
## Damage per shot = Damage + Celerity Scaling x Celerity.

## Seconds between the first shots (at 100 Celerity).
@export var start_gap: float = 0.8
## Each shot at the same enemy cuts the gap by this share (0.15 = 15%).
@export_range(0.0, 0.9, 0.01) var spin_up: float = 0.15
## The shortest gap it reaches (at 100 Celerity).
@export var min_gap: float = 0.15
## Damage each shot deals, plus this much per point of COLUMN's Celerity.
@export var damage: float = 8.0
@export var celerity_scaling: float = 0.18


func make_status() -> Status:
	return GatlingStatus.new(self)


class GatlingStatus extends Status:
	var weapon: ColumnGatlingWeapon
	var _target = null   # untyped: may be freed
	var _gap := 0.0
	var _left := 0.0

	func _init(p_weapon: ColumnGatlingWeapon) -> void:
		weapon = p_weapon
		_gap = p_weapon.start_gap

	func tick(unit: BattleUnit, delta: float) -> void:
		if not ColumnWeapon.can_act(unit):
			return
		var in_range := ColumnWeapon.enemies_in_range(unit, unit.attack_range)
		if in_range.is_empty():
			_target = null
			_gap = weapon.start_gap
			return
		var enemy: BattleUnit = _target if is_instance_valid(_target) and in_range.has(_target) else in_range[0]
		if enemy != _target:
			_target = enemy
			_gap = weapon.start_gap   # spins back down on a new enemy
		_left -= delta
		if _left > 0.0:
			return
		_left = _gap * ColumnWeapon.speed_scale(unit)
		_gap = maxf(_gap * (1.0 - weapon.spin_up), weapon.min_gap)
		var shot := Projectile.new()
		shot.is_attack = false
		var amount := Stats.scaled(weapon.damage, weapon.celerity_scaling, unit.get_stat(Stats.Stat.CELERITY))
		shot.setup(unit, enemy, amount, ColumnWeapon.LIGHT, 0, Stats.DamageType.MIGHT)
		shot.scale = Vector2(0.5, 0.5)
		unit.get_parent().add_child(shot)
		shot.global_position = unit.global_position
