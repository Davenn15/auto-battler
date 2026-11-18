class_name PlantGambit
extends Gambit
## Balmede plants herself where she stands for Duration: a Shield, all three Wards up by
## Ward Bonus, and she can't move (she still attacks whatever is in reach).
##   A: Immovability while planted.  A1: a chance to send projectiles back.
##   A2: if the Shield is still up when the Gambit ends, she gains a stack of Glory.

@export var shield: float = 300.0
@export var ward_bonus: float = 40.0
@export var duration: float = 4.0
## A: Immovability while planted (0 = none).
@export var immovability: float = 0.0
## A1: chance to reflect each incoming projectile while planted (0.35 = 35%).
@export var reflect_chance: float = 0.0
## A2: 1 = a Glory stack if the Shield outlasts the Gambit.
@export var glory_if_unbroken: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return caster.target != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for status in caster.statuses:
		if status is PlantStatus:
			caster.remove_status(status)   # a fresh plant replaces one still going
			break
	var amount := shield
	for status in caster.statuses:
		amount = status.modify_shield_received(caster, amount)
	caster.add_status(PlantStatus.new(self, amount))
	caster.get_tree().call_group("damage_tracker", "record_shielding", caster.get_instance_id(), amount)
	caster.show_float_text("Planted", BalmedeFx.COLOR)


## The plant on Balmede: its own Shield (so A2 can tell whether it broke), the Ward bonus,
## no moving, and the A-path extras.
class PlantStatus extends Status:
	const TINT := Color(0.7, 1.0, 0.95)
	const PARRY_COLOR := Color(0.8, 1.0, 0.97)
	var gambit: PlantGambit
	var shield: float
	var time_left: float
	var _ring

	func _init(p_gambit: PlantGambit, p_shield: float) -> void:
		gambit = p_gambit
		shield = p_shield
		time_left = p_gambit.duration

	func on_applied(unit: BattleUnit) -> void:
		_ring = BalmedeFx.plant_ring(unit)
		if unit.sprite != null:
			unit.sprite.self_modulate = TINT

	func on_removed(unit: BattleUnit) -> void:
		if is_instance_valid(_ring):
			_ring.queue_free()
		if unit.sprite != null:
			unit.sprite.self_modulate = Color.WHITE

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left > 0.0:
			return
		if gambit.glory_if_unbroken > 0.0 and shield > 0.0 and unit.alive:
			unit.gain_glory()
		unit.remove_status(self)

	func get_shield(_unit: BattleUnit) -> float:
		return shield

	func modify_incoming_damage(_unit: BattleUnit, damage: float) -> float:
		var absorbed := minf(shield, damage)
		shield -= absorbed
		return damage - absorbed

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
			return value + gambit.ward_bonus
		if stat == Stats.Stat.IMMOVABILITY:
			return value + gambit.immovability   # A
		return value

	func blocks_movement(_unit: BattleUnit) -> bool:
		return true

	func try_reflect(unit: BattleUnit, projectile: Projectile) -> bool:
		if gambit.reflect_chance <= 0.0 or CombatRng.randf() >= gambit.reflect_chance:
			return false
		if not projectile.reflect(unit, unit.get_stat(Stats.Stat.WRACK_CHANCE)):
			return false
		unit.show_float_text("Reflect", PARRY_COLOR)
		return true
