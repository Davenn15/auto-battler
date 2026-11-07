class_name PistolStatus
extends Status
## The unit's pistol. Shots can be stored: while any are loaded, every attack is a pistol
## shot that can be fired from farther away and is more likely to wrack. One is loaded
## after every few sword attacks; other effects can load more. While shots are loaded,
## the unit's attack range is the pistol's; it goes back to sword range when the last
## one is fired.

var every: int              # 3 = a shot loads after every two sword attacks
var pistol_range: int
var wrack_bonus: float
var max_shots: int
var _sword_range: int
var _swings: int = 0        # sword attacks since the last shot loaded on its own
var _shots: int = 0         # shots loaded and waiting
var _firing := false        # the attack being made right now is a shot
var extra_might_scaling: float   # extra damage per point of Might on shots (0.5 = 1.5x Might in total)

func _init(p_every: int, p_pistol_range: int, p_wrack_bonus: float, p_max_shots: int, p_extra_might_scaling: float) -> void:
	every = p_every
	pistol_range = p_pistol_range
	wrack_bonus = p_wrack_bonus
	max_shots = p_max_shots
	extra_might_scaling = p_extra_might_scaling

## Shots hit harder with Might than sword attacks. Runs before on_attack, so a loaded
## shot means this attack is one.
func modify_outgoing_damage(unit: BattleUnit, damage: float) -> float:
	if _shots > 0:
		return Stats.scaled(damage, extra_might_scaling, unit.get_stat(Stats.Stat.MIGHT))
	return damage

func on_applied(unit: BattleUnit) -> void:
	_sword_range = unit.attack_range


func on_removed(unit: BattleUnit) -> void:
	unit.attack_range = _sword_range


## Loads `count` more shots, up to max_shots. Her attacks fire them one at a time.
func load_shot(unit: BattleUnit, count: int = 1) -> void:
	_shots = mini(_shots + count, max_shots)
	if _shots > 0:
		unit.attack_range = pistol_range   # she can take the shots from here


func shots_loaded() -> int:
	return _shots


func modify_wrack_chance(_unit: BattleUnit, _target: BattleUnit, chance: float) -> float:
	return chance + wrack_bonus if _shots > 0 else chance


func on_attack(unit: BattleUnit) -> void:
	if _shots > 0:
		_shots -= 1
		_firing = true   # create_projectile turns this attack into a shot
		return
	_swings += 1
	if _swings >= every - 1:
		_swings = 0
		load_shot(unit)


func create_projectile(unit: BattleUnit) -> Projectile:
	if not _firing:
		return null
	_firing = false
	if _shots == 0:
		unit.attack_range = _sword_range   # that was the last one: back to the sword
	return PistolShot.new()
