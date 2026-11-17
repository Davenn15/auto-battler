class_name PistolStatus
extends Status
## The unit's pistol. Every few attacks (any kind) load a shot into it; other effects can
## load more. Whenever she attacks with a shot loaded, she uses it: that attack is a pistol
## shot, fired from farther away and more likely to wrack. While shots are loaded, her
## attack range is the pistol's; it goes back to sword range when the last one is fired.
## A row of little bullets above her status plate shows how many are loaded.

var every: int              # 3 = every third attack loads a shot
var pistol_range: int
var wrack_bonus: float
var max_shots: int
var _sword_range: int
var _attacks: int = 0       # attacks made this combat (every `every`th loads a shot)
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
	if unit.health_bar != null:
		_tracker = ShotTracker.new()
		_tracker.unit = unit
		_tracker.pistol = self
		unit.health_bar.add_child(_tracker)


func on_removed(unit: BattleUnit) -> void:
	unit.attack_range = _sword_range
	if is_instance_valid(_tracker):
		_tracker.queue_free()
	_tracker = null


## Loads `count` more shots, up to max_shots. Her attacks fire them one at a time.
func load_shot(unit: BattleUnit, count: int = 1) -> void:
	_shots = mini(_shots + count, max_shots)
	if _shots > 0:
		unit.attack_range = pistol_range   # she can take the shots from here
	_redraw_tracker()


func shots_loaded() -> int:
	return _shots


func modify_wrack_chance(_unit: BattleUnit, _target: BattleUnit, chance: float) -> float:
	return chance + wrack_bonus if _shots > 0 else chance


## Uses a loaded shot if there is one (this attack is then a pistol shot), then counts
## the attack: every `every`th one loads a shot for a later attack.
func on_attack(unit: BattleUnit) -> void:
	if _shots > 0:
		_shots -= 1
		_firing = true   # create_projectile turns this attack into a shot
	_attacks += 1
	if every > 0 and _attacks % every == 0:
		load_shot(unit)
	_redraw_tracker()


func create_projectile(unit: BattleUnit) -> Projectile:
	if not _firing:
		return null
	_firing = false
	if _shots == 0:
		unit.attack_range = _sword_range   # that was the last one: back to the sword
	return PistolShot.new()


# ---------- The shot tracker ----------

var _tracker: ShotTracker

func _redraw_tracker() -> void:
	if is_instance_valid(_tracker):
		_tracker.queue_redraw()


## A row of small brass bullets, one per loaded shot, centred just above the unit's status
## plate (above its Keepsake icons, if it has any). A child of the health bar, so it moves
## and hides with it.
class ShotTracker extends Control:
	const BULLET := Vector2(3.0, 6.0)
	const GAP := 1.0
	const BRASS := Color(1.0, 0.82, 0.45)
	const TIP := Color(0.85, 0.6, 0.35)
	const OUTLINE := Color(0.05, 0.05, 0.07, 0.9)

	var unit: BattleUnit
	var pistol: PistolStatus

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 1

	func _draw() -> void:
		if pistol == null or not is_instance_valid(unit):
			return
		var count := pistol.shots_loaded()
		if count <= 0:
			return
		var plate := unit._plate
		var center_x: float = (plate.position.x + BattleUnit.PLATE_WIDTH / 2.0) if is_instance_valid(plate) else unit.health_bar.size.x / 2.0
		var top := -BattleUnit.PLATE_PAD - 1.0 - BULLET.y
		var icons := unit._keepsake_icons
		if icons != null and is_instance_valid(icons):
			top -= BattleUnit.KEEPSAKE_ICON_SIZE + 1.0
		var row := count * BULLET.x + (count - 1) * GAP
		var x := center_x - row / 2.0
		for i in count:
			var r := Rect2(Vector2(x, top), BULLET)
			draw_rect(r.grow(0.5), OUTLINE)
			draw_rect(Rect2(r.position + Vector2(0, BULLET.y * 0.35), Vector2(BULLET.x, BULLET.y * 0.65)), BRASS)
			# A rounded tip, a shade darker, pointing up.
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, BULLET.y * 0.4),
					r.position + Vector2(0, BULLET.y * 0.15), r.position + Vector2(BULLET.x / 2.0, 0),
					r.position + Vector2(BULLET.x, BULLET.y * 0.15), r.position + Vector2(BULLET.x, BULLET.y * 0.4)]), TIP)
			x += BULLET.x + GAP
