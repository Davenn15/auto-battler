class_name BarbedFrenzyGambit
extends Gambit
## Cerceval: for Duration seconds he gains Celerity and Vampirism, and his attacks become
## blades that pierce every enemy in a line (see BarbedBlade): full damage to the first,
## Pierce Share to each one after.
##   A: each attack also throws two smaller side blades (Side Blade Share damage).
##   A2: the Celerity lasts for the rest of combat instead, stacking with every cast.

@export var duration: float = 5.0
@export var celerity: float = 50.0
@export var vampirism: float = 0.2
@export_range(0.0, 1.0, 0.05) var pierce_share: float = 0.6
## A: side blades' damage share (0 = none) and angle either side, in degrees.
@export_range(0.0, 1.0, 0.05) var side_blade_share: float = 0.0
@export var side_blade_angle: float = 12.0
## A2: 1 = each cast's Celerity lasts the rest of combat (and stacks).
@export var lasting_celerity: float = 0.0


## Only when an enemy is in reach, so the frenzy isn't spent walking.
func can_use(caster: BattleUnit) -> bool:
	return caster._enemy_in_range() != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for status in caster.statuses.duplicate():
		if status is FrenzyStatus:
			caster.remove_status(status)   # a new cast restarts it
	var lasting := lasting_celerity > 0.0
	caster.add_status(FrenzyStatus.new(self, not lasting))
	if lasting:
		caster.add_status(LastingCelerity.new(Stats.Stat.CELERITY, celerity, INF))
	caster.show_float_text(gambit_name, CercevalFx.COLOR)


class FrenzyStatus extends Status:
	var gambit: BarbedFrenzyGambit
	var with_celerity: bool
	var time_left: float

	func _init(p_gambit: BarbedFrenzyGambit, p_with_celerity: bool) -> void:
		gambit = p_gambit
		with_celerity = p_with_celerity
		time_left = p_gambit.duration

	func on_applied(unit: BattleUnit) -> void:
		KeepsakeVfx.set_glow(unit, CercevalFx.FRENZY_GLOW, Color(CercevalFx.COLOR, 0.8), 0.6)

	func on_removed(unit: BattleUnit) -> void:
		KeepsakeVfx.clear(unit, CercevalFx.FRENZY_GLOW)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat == Stats.Stat.CELERITY and with_celerity:
			return value + gambit.celerity
		if stat == Stats.Stat.VAMPIRISM:
			return value + gambit.vampirism
		return value

	func create_projectile(_unit: BattleUnit) -> Projectile:
		var blade := BarbedBlade.new()
		blade.pierce_share = gambit.pierce_share
		blade.side_share = gambit.side_blade_share
		blade.side_angle = gambit.side_blade_angle
		return blade

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)


## A2's Celerity, for the rest of combat: a permanent stat gain, so effects that react to
## those (Lordred A, Von Carrow A) see it. Unlike other statuses a Gambit gives its caster,
## it never stops him gaining Charge (it would, forever: it never ends).
class LastingCelerity extends TimedStatStatus:
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func is_permanent_stat_gain() -> bool:
		return true

	func get_permanent_stat_gains() -> Dictionary:
		return {stat: amount}
