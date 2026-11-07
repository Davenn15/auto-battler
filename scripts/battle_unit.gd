@tool

class_name BattleUnit
extends Node2D
## Grid-based auto battler unit. Scene structure: a Node2D root with this script,
## a ProgressBar named "HealthBar", plus whatever visuals you like.

signal died(unit: BattleUnit)
## Emitted when one of this unit's attacks rolls a wrack.
signal wracked(unit: BattleUnit)
## Emitted when any status is added to this unit.
signal status_added(unit: BattleUnit, status: Status)
## Emitted when this unit starts its Gambit.
signal gambit_cast(unit: BattleUnit)

# Health bar fill color per team.
const TEAM_COLORS := {
	1: Color(0.25, 0.5, 1.0),   # blue
	2: Color(0.9, 0.25, 0.25),  # red
}

const MAX_KEEPSAKES := 3

## How the battle is being looked at. Online, the joining player watches the host's fight
## turned around (the camera rotated half a turn) so their own army is at the bottom;
## each unit is turned by `view_rotation` too so it still stands upright. Purely visual.
static var view_rotation := 0.0
## True while the colours are swapped, so the local player's units are blue even when
## they're team 2.
static var swap_team_colors := false


## Health bar and shot colour for `team`, after any swap.
static func team_color(team: int) -> Color:
	var shown := (3 - team) if swap_team_colors and (team == 1 or team == 2) else team
	return TEAM_COLORS.get(shown, Color.GRAY)

## Keepsakes this unit has equipped, at most MAX_KEEPSAKES.
var keepsakes: Array[Keepsake] = []

const HEALTH_TICK_INTERVAL := 200.0   # one line per this much max health
const HEALTH_TICK_WIDTH := 1.0        # line width in pixels
const SWING_TIME := 0.12          # seconds for the sword to sweep
const SWING_ARC := 0.9            # radians either side of the aim direction
const ATTACK_BAR_COLOR := Color(1.0, 0.85, 0.3)   # gold

var attack_bar: ProgressBar
var _attack_cooldown_total: float = 1.0
var _locked_time: float = 0.0
var _stunned_time: float = 0.0   # seconds of stun left; the attack timer doesn't run meanwhile

const BLOCKED_TARGET_TIMEOUT := 1.0   # seconds unable to reach a target before giving up on it
## Effective range is attack range + this many hexes. A target that has been within
## effective range and then isn't (whoever moved) is dropped for a new one.
const RETARGET_SLACK := 1
var _blocked_time: float = 0.0

const FLOAT_RISE := 40.0    # pixels the number drifts upward
const FLOAT_TIME := 0.8     # seconds before it fades out
const FLOAT_TEXT_BOTTOM := -54.0              # where floating text's bottom edge starts, relative to the unit: above the health bar (-42) and the item icons
const FLOAT_TEXT_BOX := Vector2(60, 40)       # room for the biggest number, so it grows upward, never down onto the bar

const DAMAGE_FLASH_WINDOW := 0.15   # seconds a flash keeps collecting hits before fading
const DAMAGE_FLASH_TIME := 0.35     # seconds the flash then takes to fade
var _flash: ColorRect             # the current damage flash on the health bar
var _flash_collecting := false    # true while it's still adding up hits
var _flash_top: float             # health when the current flash started
var _flash_low: float             # lowest health since then

const DAMAGE_FONT_MIN := 7          # font size for the smallest hits
const DAMAGE_FONT_MAX := 22          # font size for hits at or above DAMAGE_FOR_MAX_FONT
const DAMAGE_FOR_MAX_FONT := 400.0   # damage that reaches the biggest size
const WRACK_FONT_BONUS := 2          # wracks are this much bigger again
const DODGE_COLOR := Color(0.464, 0.464, 0.464, 1.0)
const CHARGE_COLOR := Color(0.6, 0.4, 1.0)   # purple, so it reads differently from the team-colored health bar
const CASTING_COLOR := Color(1.0, 0.45, 0.75)   # pink, while the bar drains
var _charge_fill: StyleBoxFlat

const SHIELD_COLOR := Color(0.565, 0.565, 0.565, 0.9)   # light gray
var shield_bar: Panel
## The shield on the health bar: bright, outlined, and a pixel taller than the bar on each
## side, so even a small shield stands out from the health under it.
const SHIELD_BAR_COLOR := Color(0.92, 0.95, 1.0)      # near white, a touch of blue
const SHIELD_BAR_BORDER := Color(0.08, 0.08, 0.1)    # dark outline
const SHIELD_BAR_OVERHANG := 1.0   # pixels it sticks out above and below the health bar
const SHIELD_BAR_MIN_WIDTH := 3.0  # pixels, so a tiny shield is still visible
const PENDING_COLOR := Color(0.45, 0.05, 0.05)   # dark red: health about to be lost
var pending_bar: ColorRect

const BADGE_SIZE := 6.0   # pixels, square
const BADGE_GAP := 2.0    # between badges, and between the badges and the health bar
## Badge color for the first and second choice at level 1. Shared by every unit.
const PATH_COLORS: Array[Color] = [Color(0.94, 0.55, 0.16), Color(0.18, 0.72, 0.69)]   # orange, teal
## How far a level-2 badge is shaded from its path color: lighter for the first
## follow-up, darker for the second.
const FOLLOW_UP_SHADE := 0.4

const KEEPSAKE_ICON_SIZE := 8.0   # pixels, square: the item icons above the health bar



## Optional. When set, its stats replace the values below.
@export var data: UnitData:
	set(value):
		data = value
		_refresh_editor_preview()
@export var team: int = 1
## Which upgrade was picked at each level, as indices into the choices offered.
## [] = not upgraded, [1] = second choice at level 1, [1, 0] = then the first of its follow-ups.
## The shop will set this later; for now set it in the Inspector to test.
@export var upgrade_path: Array[int] = []


var max_health: float

var move_speed: float    # pixels/sec while sliding between cells
var attack_range: int       # measured in hex cells
var health_regen: float = 2.0

var statuses: Array[Status] = []

@export var passives: Array[Passive] = []

var gambit: Gambit
var _casting: bool = false
var _cast_timer: float = 0.0
var max_charge: float = 100.0
var starting_charge: float = 0.0
var charge_on_attack: float = 10.0       # flat, when this unit's attack hits
var charge_on_hit: float = 5.0           # flat, when this unit takes an attack hit
var charge_per_damage: float = 0.02      # extra charge per point of damage taken
var charge: float = 0.0
var charge_bar: ProgressBar
var _cast_total: float = 0.0   # length of the cast in progress, for the bar
## Damage this unit has dealt this battle, including its summons'. For effects that
## care who has been hitting hardest.
var damage_dealt: float = 0.0

@onready var sprite: Sprite2D = $Sprite

var auto_place: bool = true   # snap to the nearest cell in _ready(); spawners turn this off

var health: float
var cell: Vector2i            # the cell this unit is logically standing in
var target: BattleUnit = null
var active: bool = false      # set true when the combat phase starts
var alive: bool = true


var grid: BattleGrid
var health_bar: ProgressBar
var _moving: bool = false
var _dest_cell: Vector2i
var _dest_world: Vector2
var _attack_timer: float = 0.0

## True for units created mid-battle by another unit (clones, summons).
var is_summon: bool = false
var _summon_max_health: float = 0.0
var _summon_stats: Dictionary = {}
var _summoner_id: int = 0   # who a summon's damage is credited to

func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()
		return
	
	rotation = view_rotation
	add_to_group("units")
	add_to_group("damage_tracker")   # hears every damage report and keeps its own total

	grid = get_tree().get_first_node_in_group("battle_grid") as BattleGrid
	if grid == null:
		push_error("BattleUnit needs a BattleGrid in the scene.")
		return

	_apply_data()
	health = max_health
	_setup_health_bar()
	
	_setup_upgrade_badges()
	_setup_keepsake_icons()
	
	charge = starting_charge
	_setup_charge_bar()
	
	_setup_attack_bar()

	# Units placed by hand in the editor snap to the nearest cell. Units created by
	# a spawner set auto_place = false and call place_at() themselves.
	if auto_place:
		var start_cell := grid.world_to_cell(global_position)
		if not grid.has_cell(start_cell):
			push_error("%s is placed outside the grid." % name)
			return
		if grid.is_occupied(start_cell):
			push_warning("%s shares a cell with another unit." % name)
		place_at(start_cell)



## Reserve buffs bought in the match shop once the unit was fully upgraded.
var buffs: int = 0

## Copies stats from the UnitData resource, if one is assigned.
func _apply_data() -> void:
	if data == null:
		return
	var chosen := get_chosen_upgrades()
	var level := chosen.size()
	max_health = data.max_health * Stats.upgrade_health_multiplier(level) * Stats.tier_health_multiplier(data.tier) \
			* Stats.buff_health_multiplier(buffs)
	for keepsake in keepsakes:
		max_health += keepsake.health
	move_speed = 120
	attack_range = data.attack_range_cells
	health_regen = data.health_regen
	passives = data.passives.duplicate()   # a copy, so we never add to the shared resource
	gambit = data.gambit
	var bonuses := {}   # property name -> total amount to add
	var overrides := {}   # property name -> value to set
	for upgrade in chosen:
		passives.append_array(upgrade.passives)
		attack_range += upgrade.attack_range_bonus
		if upgrade.gambit != null:
			gambit = upgrade.gambit
			bonuses.clear()   # earlier bonuses were for the old Gambit
			overrides.clear()
		for property in upgrade.gambit_bonuses:
			bonuses[property] = bonuses.get(property, 0.0) + upgrade.gambit_bonuses[property]
		overrides.merge(upgrade.gambit_overrides, true)
	if gambit != null and not (bonuses.is_empty() and overrides.is_empty()):
		gambit = _gambit_with_changes(gambit, bonuses, overrides)
	max_charge = data.max_charge
	starting_charge = data.starting_charge
	charge_on_attack = data.charge_on_attack
	charge_on_hit = data.charge_on_hit
	charge_per_damage = data.charge_per_damage
	for stat in Stats.Stat.values():
		base_stats[stat] = data.get_base_stat(stat) * Stats.upgrade_multiplier(stat, level) * Stats.tier_multiplier(stat, data.tier) \
				* Stats.buff_multiplier(stat, buffs)
	attack_damage_type = data.attack_damage_type
	if data.sprite != null and sprite != null:
		sprite.texture = data.sprite
	if is_summon:
		max_health = _summon_max_health
		base_stats = _summon_stats
		gambit = null   # summons don't cast

## A copy of `base` with bonuses added to, and overrides replacing, the matching properties.
func _gambit_with_changes(base: Gambit, bonuses: Dictionary, overrides: Dictionary) -> Gambit:
	var copy := base.duplicate() as Gambit   # this unit's own copy; never change the shared file
	for property in bonuses:
		if _gambit_has(copy, property):
			var current = copy.get(property)
			copy.set(property, current + type_convert(bonuses[property], typeof(current)))
	for property in overrides:
		if _gambit_has(copy, property):
			copy.set(property, type_convert(overrides[property], typeof(copy.get(property))))
	return copy


func _gambit_has(gambit_copy: Gambit, property: String) -> bool:
	if property in gambit_copy:
		return true
	push_warning("%s: upgrade changes unknown Gambit property '%s'." % [name, property])
	return false

## Editor-only preview: shows the profile's sprite and name on the unit.
func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	if data != null and data.sprite != null and sprite != null:
		sprite.texture = data.sprite
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint() and data != null:
		# Centered under the unit; adjust the offset to suit your sprite size.
		draw_string(ThemeDB.fallback_font, Vector2(-40, 44), data.display_name,
				HORIZONTAL_ALIGNMENT_CENTER, 80.0, 14)

func _setup_health_bar() -> void:
	health_bar = find_child("HealthBar", true, false) as ProgressBar
	if health_bar == null:
		push_warning("%s: no ProgressBar named 'HealthBar' found under this unit." % name)
		return

	# Color the fill by team (1 = blue, 2 = red).
	var fill := StyleBoxFlat.new()
	fill.bg_color = team_color(team)
	health_bar.add_theme_stylebox_override("fill", fill)

	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	_update_health_bar()
	_setup_health_ticks()
	_update_health_ticks()
	_setup_pending_bar()   # before the shield bar, so the shield draws on top
	_setup_shield_bar()


func _update_health_bar() -> void:
	if health_bar != null:
		health_bar.value = maxf(health, 0.0)

var _health_ticks: Array[ColorRect] = []

## Draws a thin black line on the health bar at every HEALTH_TICK_INTERVAL of max health.
func _setup_health_ticks() -> void:
	if health_bar == null or max_health <= 0.0:
		return
	var count := int(max_health / HEALTH_TICK_INTERVAL)
	for i in range(1, count + 1):
		var frac := (i * HEALTH_TICK_INTERVAL) / max_health
		if frac >= 1.0:
			break   # no line on the bar's right edge
		var tick := ColorRect.new()
		tick.color = Color.BLACK
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Anchors are fractions of the parent's width, so this works whatever the bar's size.
		tick.anchor_left = frac
		tick.anchor_right = frac
		tick.anchor_top = 0.0
		tick.anchor_bottom = 1.0
		tick.offset_left = -HEALTH_TICK_WIDTH / 2.0
		tick.offset_right = HEALTH_TICK_WIDTH / 2.0
		tick.offset_top = 0.0
		tick.offset_bottom = 0.0
		health_bar.add_child(tick)
		_health_ticks.append(tick)
	_update_health_ticks()

## Only shows lines at or below the unit's current health.
func _update_health_ticks() -> void:
	for i in _health_ticks.size():
		_health_ticks[i].visible = (i + 1) * HEALTH_TICK_INTERVAL <= health

func _setup_pending_bar() -> void:
	pending_bar = ColorRect.new()
	pending_bar.color = PENDING_COLOR
	pending_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pending_bar.visible = false
	health_bar.add_child(pending_bar)   # child of the health bar, so it draws on top of it


## Darkens the end of the health bar by the damage the unit is still due to take.
func _update_pending_bar() -> void:
	if pending_bar == null or health_bar == null or max_health <= 0.0:
		return
	var pending := minf(get_pending_damage(), maxf(health, 0.0))
	if pending <= 0.0:
		pending_bar.visible = false
		return
	var width := health_bar.size.x
	var start_frac := (health - pending) / max_health
	var end_frac := health / max_health
	pending_bar.position = Vector2(start_frac * width, 0.0)
	pending_bar.size = Vector2((end_frac - start_frac) * width, health_bar.size.y)
	pending_bar.visible = true


func _setup_shield_bar() -> void:
	shield_bar = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SHIELD_BAR_COLOR
	style.border_color = SHIELD_BAR_BORDER
	style.set_border_width_all(1)
	shield_bar.add_theme_stylebox_override("panel", style)
	shield_bar.z_index = 1   # above the health tick lines, which can be rebuilt later
	shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_bar.visible = false
	health_bar.add_child(shield_bar)   # child of the health bar, so it draws on top of it


func _update_shield_bar() -> void:
	if shield_bar == null or health_bar == null or max_health <= 0.0:
		return
	var current := get_shield()
	if current <= 0.0:
		shield_bar.visible = false
		return
	var width := health_bar.size.x
	var shield_frac := current / max_health
	# The shield sits at the end of current health, but can't run past the bar's right edge.
	var end_frac := minf(health + current, max_health) / max_health
	var start_frac := maxf(end_frac - shield_frac, 0.0)
	var shield_width := maxf((end_frac - start_frac) * width, SHIELD_BAR_MIN_WIDTH)
	var left := minf(start_frac * width, width - shield_width)   # a widened shield stays inside the bar
	shield_bar.position = Vector2(left, -SHIELD_BAR_OVERHANG)
	shield_bar.size = Vector2(shield_width, health_bar.size.y + SHIELD_BAR_OVERHANG * 2.0)
	shield_bar.visible = true

## Flashes white the part of the health bar a hit just took. Hits that land within
## DAMAGE_FLASH_WINDOW of the first share one flash, so a volley of small hits reads
## as one chunk of damage.
func _flash_health_loss(from_health: float, to_health: float) -> void:
	if health_bar == null or max_health <= 0.0 or from_health <= to_health:
		return
	if not _flash_collecting or not is_instance_valid(_flash):
		_start_flash(from_health)
	_flash_low = minf(_flash_low, to_health)
	_size_flash()


## Starts a new flash at `from_health`. It collects hits for DAMAGE_FLASH_WINDOW, then
## fades and removes itself. An older flash that's still fading is left to finish.
func _start_flash(from_health: float) -> void:
	_flash = ColorRect.new()
	_flash.color = Color.WHITE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_child(_flash)   # a child of the bar, so it draws on top of it
	_flash_top = from_health
	_flash_low = from_health
	_flash_collecting = true
	var tween := _flash.create_tween()
	tween.tween_interval(DAMAGE_FLASH_WINDOW)
	tween.tween_callback(func(): _flash_collecting = false)
	tween.tween_property(_flash, "modulate:a", 0.0, DAMAGE_FLASH_TIME)
	tween.tween_callback(_flash.queue_free)


## Stretches the current flash from the lowest health it has seen up to where it started.
func _size_flash() -> void:
	var width := health_bar.size.x
	var start := maxf(_flash_low, 0.0) / max_health
	var end := minf(_flash_top, max_health) / max_health
	_flash.position = Vector2(start * width, 0.0)
	_flash.size = Vector2((end - start) * width, health_bar.size.y)

var _badges: HBoxContainer

## Small badges to the left of the health bar, one per upgrade taken. How many = level;
## colors (or icons) = which path. Safe to call again if the upgrades change.
func _setup_upgrade_badges() -> void:
	if _badges != null:
		_badges.queue_free()
		_badges = null
	if health_bar == null:
		return
	var chosen := get_chosen_upgrades()
	if chosen.is_empty():
		return
	_badges = HBoxContainer.new()
	_badges.add_theme_constant_override("separation", int(BADGE_GAP))
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for level in chosen.size():
		_badges.add_child(_make_badge(_badge_color(level)))
	health_bar.add_child(_badges)   # a child of the bar, so it moves with it
	var width := chosen.size() * BADGE_SIZE + (chosen.size() - 1) * BADGE_GAP
	_badges.position = Vector2(-width - BADGE_GAP, (health_bar.size.y - BADGE_SIZE) / 2.0)


## A small square of the given color.
func _make_badge(color: Color) -> Control:
	var badge := ColorRect.new()
	badge.color = color
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge


## The color of the badge for upgrade `level` (0 = first upgrade), from the choices
## in upgrade_path.
func _badge_color(level: int) -> Color:
	var path_color := PATH_COLORS[upgrade_path[0] % PATH_COLORS.size()]
	if level == 0:
		return path_color
	return path_color.lightened(FOLLOW_UP_SHADE) if upgrade_path[level] == 0 else path_color.darkened(FOLLOW_UP_SHADE)


var _keepsake_icons: HBoxContainer

## A small icon above the health bar for each equipped keepsake, centred over the bar.
## Safe to call again whenever the keepsakes change.
func _setup_keepsake_icons() -> void:
	if _keepsake_icons != null:
		_keepsake_icons.queue_free()
		_keepsake_icons = null
	if health_bar == null or keepsakes.is_empty():
		return
	_keepsake_icons = HBoxContainer.new()
	_keepsake_icons.add_theme_constant_override("separation", int(BADGE_GAP))
	_keepsake_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for keepsake in keepsakes:
		var icon := TextureRect.new()
		icon.texture = keepsake.get_icon()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.custom_minimum_size = Vector2(KEEPSAKE_ICON_SIZE, KEEPSAKE_ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_keepsake_icons.add_child(icon)
	health_bar.add_child(_keepsake_icons)   # a child of the bar, so it moves with it
	var width := keepsakes.size() * KEEPSAKE_ICON_SIZE + (keepsakes.size() - 1) * BADGE_GAP
	_keepsake_icons.position = Vector2((health_bar.size.x - width) / 2.0, -KEEPSAKE_ICON_SIZE - BADGE_GAP)

## Moves the unit onto `new_cell`, keeping position, `cell`, and grid occupancy in sync.
func place_at(new_cell: Vector2i) -> void:
	grid.vacate(cell, self)   # no-op if we weren't holding that cell
	cell = new_cell
	global_position = grid.cell_to_world(new_cell)
	grid.occupy(new_cell, self)

## Turns this unit into a summon copying `source`: same profile and current base stats,
## a fraction of its max health, and no Gambit. Call before adding it to the scene.
func setup_as_summon(source: BattleUnit, health_fraction: float) -> void:
	data = source.data
	team = source.team
	auto_place = false   # the summoner places it
	is_summon = true
	_summon_max_health = source.max_health * health_fraction
	_summon_stats = source.base_stats.duplicate()
	_summoner_id = source.get_credit_id()

## Turns this unit into a summon that looks like `profile` (name, sprite) but takes its
## numbers from `source`: `health_fraction` of its max health and its base stats, with
## all three wards multiplied by `ward_multiplier`. Fights for `source`'s team and
## credits its damage to it. Call before adding it to the scene.
func setup_as_profile_summon(profile: UnitData, source: BattleUnit, health_fraction: float,
		ward_multiplier: float = 1.0) -> void:
	data = profile
	team = source.team
	auto_place = false   # the summoner places it
	is_summon = true
	_summon_max_health = source.max_health * health_fraction
	_summon_stats = source.base_stats.duplicate()
	for ward in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
		_summon_stats[ward] *= ward_multiplier
	_summoner_id = source.get_credit_id()

## The id this unit's damage is credited to on the damage meter: its summoner for
## summons, itself otherwise.
func get_credit_id() -> int:
	return _summoner_id if is_summon else get_instance_id()

## Kills the unit outright, for effects that end it rather than damage it.
func kill() -> void:
	if not alive:
		return
	health = 0.0
	_update_health_bar()
	_die()

## The Upgrade resources picked so far, in order, found by walking the unit's tree.
func get_chosen_upgrades() -> Array[Upgrade]:
	var chosen: Array[Upgrade] = []
	if data == null:
		return chosen
	var choices := data.upgrades
	for index in upgrade_path:
		if index < 0 or index >= choices.size():
			push_warning("%s: upgrade choice %d doesn't exist." % [name, index])
			break
		var upgrade := choices[index]
		chosen.append(upgrade)
		choices = upgrade.next_choices   # the next level's options come from this pick
	return chosen


func get_upgrade_level() -> int:
	return get_chosen_upgrades().size()

func record_damage(unit_id: int, amount: float) -> void:
	if unit_id == get_instance_id():
		damage_dealt += amount
		var vampirism := get_stat(Stats.Stat.VAMPIRISM)
		if vampirism > 0.0 and amount > 0.0:
			heal(amount * vampirism)


func record_healing(_unit_id: int, _amount: float) -> void:
	pass


func record_shielding(_unit_id: int, _amount: float) -> void:
	pass

## Equips a keepsake if there's a free slot. Returns false if the unit is full.
func equip(keepsake: Keepsake) -> bool:
	if keepsake == null or keepsakes.size() >= MAX_KEEPSAKES:
		return false
	keepsakes.append(keepsake)
	_keepsakes_changed()
	return true


## Takes one copy of `keepsake` off the unit. Returns false if it wasn't equipped.
func unequip(keepsake: Keepsake) -> bool:
	var index := keepsakes.find(keepsake)
	if index == -1:
		return false
	keepsakes.remove_at(index)
	_keepsakes_changed()
	return true


## After equipping or unequipping: recompute max health from the keepsakes' Health,
## move current health by the same amount (never below 1), and redraw the bar and icons.
func _keepsakes_changed() -> void:
	var had := max_health
	_apply_data()
	health = maxf(health + max_health - had, 1.0)
	if health_bar != null:
		health_bar.max_value = max_health
		for tick in _health_ticks:
			tick.queue_free()
		_health_ticks.clear()
		_setup_health_ticks()   # tick lines depend on max health
	_update_health_bar()
	_setup_keepsake_icons()
	_update_sprite_size()


## Units wearing the Health + Health keepsake are drawn a little bigger.
const BIG_SPRITE_SCALE := 1.15
var _base_sprite_scale := Vector2.ZERO

func _update_sprite_size() -> void:
	if sprite == null:
		return
	if _base_sprite_scale == Vector2.ZERO:
		_base_sprite_scale = sprite.scale
	var big := keepsakes.any(func(k): return k.effect is RegenShareEffect)
	sprite.scale = _base_sprite_scale * (BIG_SPRITE_SCALE if big else 1.0)

func start_combat() -> void:
	# Safety net: the stored cell must match where the unit is actually standing.
	clear_statuses()
	for passive in passives:
		passive.on_battle_start(self)
	for keepsake in keepsakes:
		add_status(KeepsakeStatsStatus.new(keepsake))
		if keepsake.effect != null:
			keepsake.effect.on_battle_start(self)
	_casting = false
	var actual := grid.world_to_cell(global_position)
	if actual != cell:
		push_warning("%s: stored cell %s doesn't match its position (cell %s). Something placed or moved it without place_at()." % [name, cell, actual])
		if grid.has_cell(actual):
			place_at(actual)
	charge = starting_charge
	_update_charge_bar()
	active = true
	_locked_time = 0.0
	_stunned_time = 0.0
	damage_dealt = 0.0



func stop_combat() -> void:
	_casting = false
	_update_charge_bar()
	active = false   # a step already in progress still finishes, so units stay on-grid
	_locked_time = 0.0
	_stunned_time = 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not alive:
		return

	if _stunned_time > 0.0:
		_stunned_time -= delta   # stunned: no winding up an attack
	elif not _is_channeling():
		_attack_timer = maxf(_attack_timer - delta, 0.0)
	for status in statuses.duplicate():
		status.tick(self, delta)
	_update_shield_bar()
	_update_pending_bar()
	_update_attack_bar()
	if active:
		heal(get_health_regen() * delta, 0, false)



	# Finish any step in progress before making a new decision.
	if _moving:
		_continue_step(delta)
		return

	if not active:
		return

	if _locked_time > 0.0:
		_locked_time -= delta
		return

	if _casting:
		_cast_timer -= delta
		_update_charge_bar()
		if _cast_timer <= 0.0:
			_finish_gambit()
		return

	if not _is_valid_target(target):
		target = null
	if target == null:
		target = _choose_target()
		_blocked_time = 0.0
	if _ready_to_gambit():
		_begin_gambit()
		return
	if target == null:
		return

	var dist := grid.get_distance(cell, target.cell)
	if dist <= attack_range + RETARGET_SLACK:
		_reached_target = target
	elif _reached_target == target:
		# The target was within effective range and no longer is, usually because this
		# unit had to path away from it to reach a free cell. Drop it and pick someone
		# else, instead of walking all the way around the enemy team.
		target = _choose_target(target)
		_reached_target = null
		_blocked_time = 0.0
		if target == null:
			return
		dist = grid.get_distance(cell, target.cell)
	if dist <= attack_range:
		if _attack_timer <= 0.0:
			_attack(target)
		return
	_start_step()

## True while the unit is busy with its Gambit: casting it, or held in place by one
## (dashes, channels, flurries, tosses). Its attack timer doesn't wind up meanwhile.
func _is_channeling() -> bool:
	return _casting or _locked_time > 0.0

## The target that has been within effective range (attack range + RETARGET_SLACK) since
## it was picked. Untyped: it may be freed. Leaving effective range drops that target.
var _reached_target = null

## The free cell nearest to this unit from which it could hit its target.
## Returns the unit's own cell if every such cell is taken.
func _pick_attack_cell() -> Vector2i:
	var best := cell
	var best_dist := INF
	for c in grid.free_cells_in_range(target.cell, attack_range):
		var d := global_position.distance_squared_to(grid.cell_to_world(c))
		if d < best_dist:
			best_dist = d
			best = c
	return best

func _start_step() -> void:
	var goal := _pick_attack_cell()
	var next := cell if goal == cell else grid.get_next_step(cell, goal)
	if next == cell:
		# No free path right now. Keep trying, but give up on this target if it stays unreachable.
		_blocked_time += get_physics_process_delta_time()
		if _blocked_time >= BLOCKED_TARGET_TIMEOUT:
			var blocked := target
			target = _choose_target(blocked)   # pick someone else
			_blocked_time = 0.0
		return
	_blocked_time = 0.0
	_dest_cell = next
	_dest_world = grid.cell_to_world(next)
	grid.occupy(next, self)   # reserve the destination immediately
	_moving = true


func _continue_step(delta: float) -> void:
	global_position = global_position.move_toward(_dest_world, move_speed * delta)
	if global_position.is_equal_approx(_dest_world):
		grid.vacate(cell, self)   # release the old cell only once we've arrived
		cell = _dest_cell
		_moving = false


func _find_nearest_enemy(exclude: BattleUnit = null) -> BattleUnit:
	var best: BattleUnit = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as BattleUnit
		if u == null or u == exclude or not _is_valid_target(u):
			continue
		var d := grid.get_distance(cell, u.cell)
		if d < best_dist:
			best_dist = d
			best = u
	return best

## Who to target next: the nearest enemy, unless a status says otherwise.
func _choose_target(exclude: BattleUnit = null) -> BattleUnit:
	var choice := _find_nearest_enemy(exclude)
	for status in statuses:
		choice = status.modify_target_choice(self, choice, exclude)
	return choice

func _is_valid_target(u) -> bool:
	return is_instance_valid(u) and u.alive and u.team != team and u.is_targetable()

var base_stats: Dictionary = {
	Stats.Stat.MIGHT: 100.0,
	Stats.Stat.INSIGHT: 100.0,
	Stats.Stat.CELERITY: 100.0,
	Stats.Stat.MIGHT_WARD: 20.0,
	Stats.Stat.INSIGHT_WARD: 20.0,
	Stats.Stat.CELERITY_WARD: 20.0,
	Stats.Stat.WRACK_CHANCE: 0.25,
	Stats.Stat.WRACK_DAMAGE: 0.3,
	Stats.Stat.VAMPIRISM: 0
}
var attack_damage_type: int = Stats.DamageType.MIGHT

## Moves to `dest` straight away as far as the grid is concerned, and slides there on
## screen over `time` seconds. Await it to wait for the slide to finish.
func dash_to(dest: Vector2i, time: float) -> void:
	if dest == cell:
		return
	var start := global_position
	place_at(dest)   # the logical move is instant; the slide below is only visual
	var end := global_position
	global_position = start
	create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(self, "global_position", end, time)
	await get_tree().create_timer(time, true, true).timeout

## A stat's current value: the unit's base, then every status's adjustments, then any
## final adjustments.
func get_stat(stat: Stats.Stat) -> float:
	var value := get_stat_before_final(stat)
	for status in statuses:
		value = status.modify_final_stat(self, stat, value)
	return maxf(value, 0.0)


## A stat after every status's normal adjustment but before final ones. For statuses
## that turn one stat into another; everything else should use get_stat.
func get_stat_before_final(stat: Stats.Stat) -> float:
	var value: float = base_stats.get(stat, 0.0)
	for status in statuses:
		value = status.modify_stat(self, stat, value)
	return value

## Wrack damage against a particular target, after statuses that care who's being hit.
func get_wrack_damage_against(target: BattleUnit) -> float:
	var value := get_stat(Stats.Stat.WRACK_DAMAGE)
	for status in statuses:
		value = status.modify_wrack_damage(self, target, value)
	return value

## Aura spent on this unit: its purchase price plus any upgrades.
func get_aura_value() -> int:
	if data == null or is_summon:
		return 0
	return Economy.unit_aura_value(data.tier, get_upgrade_level())


## Reserve spent on this unit: its keepsakes.
func get_reserve_value() -> int:
	var total := 0
	for keepsake in keepsakes:
		total += keepsake.get_reserve_value()
	return total

func _attack(enemy: BattleUnit, extra_damage: float = 0.0, extra_wrack_chance: float = 0.0,
		projectile: Projectile = null, extra_hit_effects: Array[HitEffect] = []) -> int: 
	_attack_timer = get_attack_cooldown()
	_attack_cooldown_total = _attack_timer
	var chance := get_stat(Stats.Stat.WRACK_CHANCE)
	for status in statuses:
		chance = status.modify_wrack_chance(self, enemy, chance)
	var wrack_level := Stats.roll_wrack(chance + extra_wrack_chance)
	if wrack_level >= 3:
		show_float_text("UBER!", Stats.UBER_WRACK_COLOR)
	elif wrack_level == 2:
		show_float_text("Hyper!", Stats.HYPER_WRACK_COLOR)
	var base_damage := Stats.attack_damage(get_stat(Stats.Stat.MIGHT)) + extra_damage
	var shot_color: Color = team_color(team)
	var hit_effects: Array[HitEffect] = []
	for status in statuses.duplicate():
		base_damage = status.modify_outgoing_damage(self, base_damage)
		shot_color = status.modify_projectile_color(self, shot_color)
		var effect : HitEffect = status.get_hit_effect(self)
		if effect != null:
			hit_effects.append(effect)
		status.on_attack(self)
	hit_effects.append_array(extra_hit_effects)
	var hit_damage := base_damage * Stats.wrack_multiplier(wrack_level, get_wrack_damage_against(enemy))
	if attack_range > 1 or projectile != null:
		_fire_projectile(enemy, hit_damage, wrack_level, shot_color, hit_effects, projectile)
		return wrack_level
	_play_melee_swing(enemy.global_position)
	var dealt := enemy.take_damage(hit_damage, wrack_level, get_attack_damage_type(), ignores_wards(), self)
	get_tree().call_group("damage_tracker", "record_damage", get_credit_id(), dealt)
	gain_charge_from_attack(dealt, enemy)
	enemy.gain_charge_from_hit(dealt)
	enemy.notify_attacked(self, dealt)
	notify_attack_hit(enemy, dealt)
	run_hit_effects(hit_effects, enemy, dealt, wrack_level)
	return wrack_level

## Tells this unit's statuses an enemy's attack reached it.
func notify_attacked(attacker: BattleUnit, dealt: float) -> void:
	for status in statuses.duplicate():
		status.on_attacked(self, attacker, dealt)

func notify_attack_hit(enemy: BattleUnit, dealt: float) -> void:
	if dealt <= 0.0:
		return   # a dodge: nothing that happens "on hit" should trigger
	for status in statuses.duplicate():
		status.on_attack_hit(self, enemy, dealt)
	if not enemy.alive:
		for status in statuses.duplicate():
			status.on_kill(self, enemy)


## True wile any status says this unit's damage skips wards.
func ignores_wards() -> bool:
	for status in statuses:
		if status.ignores_wards(self):
			return true
	return false
## Runs the effects an attack collected when it was made. A dodged hit (nothing dealt)
## runs none, the same rule as charge.

static func run_hit_effects(effects: Array[HitEffect], hit_target: BattleUnit, dealt: float, wrack_level: int) -> void:
	if dealt <= 0.0:
		return
	for effect in effects:
		effect.apply(hit_target, dealt, wrack_level)

func _fire_projectile(enemy: BattleUnit, hit_damage: float, wrack_level: int, color: Color,
		hit_effects: Array[HitEffect], projectile: Projectile = null) -> void:
	if projectile == null:
		for status in statuses:
			projectile = status.create_projectile(self)
			if projectile != null:
				break
	if projectile == null:
		projectile = Projectile.new()
	projectile.ignore_ward = projectile.ignore_ward or ignores_wards()
	projectile.setup(self, enemy, hit_damage, color, wrack_level, get_attack_damage_type(), hit_effects)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position


## Set by effects that draw their own swing for an extra attack (Ghost Strike, Mage
## Hunter), so the unit's normal white swing doesn't play on top of it.
var hide_next_swing: bool = false

func _play_melee_swing(target_pos: Vector2) -> void:
	if hide_next_swing:
		return
	var color := Color.WHITE
	for status in statuses:
		color = status.modify_swing_color(self, color)
	KeepsakeVfx.swing(self, (target_pos - global_position).angle(), color)

## The unit's current time between attacks, after status effects.
func get_attack_cooldown() -> float:
	var cooldown := Stats.attack_cooldown(get_stat(Stats.Stat.CELERITY))
	for status in statuses:
		cooldown = status.modify_attack_cooldown(self, cooldown)
	return maxf(cooldown, 0.05)   # floor so stacking can never reach zero

## The damage type of the unit's basic attacks, after status effects.
func get_attack_damage_type() -> int:
	var damage_type := attack_damage_type
	for status in statuses:
		damage_type = status.modify_attack_damage_type(self, damage_type)
	return damage_type

## The unit's chance to avoid a hit entirely, after status effects.
func get_dodge_chance() -> float:
	var chance := 0.0
	for status in statuses:
		chance = status.modify_dodge_chance(self, chance)
	return clampf(chance, 0.0, 1.0)

func _setup_attack_bar() -> void:
	attack_bar = ProgressBar.new()
	attack_bar.show_percentage = false
	attack_bar.min_value = 0.0
	attack_bar.max_value = 1
	attack_bar.step = 0.0   # smooth fill instead of snapping to 0.01
	attack_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	attack_bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ATTACK_BAR_COLOR
	attack_bar.add_theme_stylebox_override("fill", fill)
	add_child(attack_bar)


func _update_attack_bar() -> void:
	if attack_bar == null or health_bar == null:
		return
	# Sit just under the health and charge bars, matching their combined width.
	var rect := health_bar.get_global_rect()
	if charge_bar != null:
		rect = rect.merge(charge_bar.get_global_rect())
	attack_bar.global_position = Vector2(rect.position.x, rect.end.y + 1.0)
	attack_bar.size = Vector2(rect.size.x, 3.0)

	if _attack_cooldown_total > 0.0:
		attack_bar.value = 1.0 - _attack_timer / _attack_cooldown_total
	else:
		attack_bar.value = 1.0

## Keeps the unit from moving, attacking, or using a Gambit for `duration` seconds.
## For Gambits that control the unit themselves (dashes, channels). Also blocks charge gain.
func lock_for(duration: float) -> void:
	_locked_time = maxf(_locked_time, duration)

const STUN_TINT := Color(0.55, 0.55, 0.55)   # sprite darkens while stunned

## True while something makes the unit immune to crowd control. Every CC effect checks this.
func is_cc_immune() -> bool:
	for status in statuses:
		if status.blocks_crowd_control(self):
			return true
	return false

## False while a status hides the unit from enemies (see Status.blocks_targeting).
func is_targetable() -> bool:
	for status in statuses:
		if status.blocks_targeting(self):
			return false
	return true

## Gives this unit's statuses a chance to send an incoming projectile away.
func try_reflect(projectile: Projectile) -> bool:
	for status in statuses.duplicate():
		if status.try_reflect(self, projectile):
			return true
	return false

## Rolls a wrack for something other than an attack. Returns 0 unless the ability can
## wrack on its own (`already_can`) or one of this unit's statuses lets this kind wrack.
func roll_effect_wrack(kind: Stats.EffectKind, already_can: bool = false) -> int:
	if not (already_can or can_wrack_kind(kind)):
		return 0
	return Stats.roll_wrack(get_stat(Stats.Stat.WRACK_CHANCE))


## True if any status lets this kind of effect from the unit wrack.
func can_wrack_kind(kind: Stats.EffectKind) -> bool:
	for status in statuses:
		if status.lets_wrack(self, kind):
			return true
	return false


## What a wrack at `level` multiplies an effect's numbers by: the unit's wrack damage,
## plus the Gambit bonus for Gambit damage that could already wrack.
func effect_wrack_multiplier(level: int, kind: Stats.EffectKind, already_can: bool = false) -> float:
	var wrack_damage := get_stat(Stats.Stat.WRACK_DAMAGE)
	if kind == Stats.EffectKind.GAMBIT_DAMAGE and already_can:
		for status in statuses:
			wrack_damage += status.gambit_wrack_bonus(self)
	return Stats.wrack_multiplier(level, wrack_damage)


## Rolls and returns the multiplier in one go, for effects that only need the number.
## `at` is where to show the wrack's flourish (the unit it affects); it defaults to this unit.
func wrack_effect_multiplier(kind: Stats.EffectKind, already_can: bool = false, at: Node2D = null) -> float:
	var level := roll_effect_wrack(kind, already_can)
	if level > 0:
		var color := KeepsakeVfx.HEAL_WRACK_COLOR if kind == Stats.EffectKind.HEALING else KeepsakeVfx.CONTROL_WRACK_COLOR
		KeepsakeVfx.flourish(at if at != null else self, color)
	return effect_wrack_multiplier(level, kind, already_can)

## Stops the unit from moving, attacking, or using its Gambit for `duration` seconds.
## A step already in progress still finishes, so the unit stays on the grid.
func stun(duration: float, source: BattleUnit = null) -> void:
	if not alive or duration <= 0.0:
		return
	if is_instance_valid(source):
		duration *= source.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, self)
	if is_cc_immune():
		show_float_text("Immune", DODGE_COLOR)
		return
	lock_for(duration)
	_stunned_time = maxf(_stunned_time, duration)
	if sprite != null:
		sprite.modulate = STUN_TINT
		sprite.create_tween().tween_property(sprite, "modulate", Color.WHITE, duration)

## Ends any stun or lock right away, for effects like waking up.
func clear_stun() -> void:
	_locked_time = 0.0
	_stunned_time = 0.0

## Makes the unit attack `enemy` right now, ignoring range and attack timing. It's a real
## attack: it can wrack, triggers on-attack effects, and resets the attack timer.
## Gambits can make it stronger: `extra_damage` is added before damage buffs apply,
## `extra_wrack_chance` adds to the wrack roll, and `projectile` replaces the normal shot.
func attack_now(enemy: BattleUnit, extra_damage: float = 0.0, extra_wrack_chance: float = 0.0,
		projectile: Projectile = null, extra_hit_effects: Array[HitEffect] = []) -> int:
	if alive and is_instance_valid(enemy) and enemy.alive:
		return _attack(enemy, extra_damage, extra_wrack_chance, projectile, extra_hit_effects)      # 2. passes the answer on
	return false                                                                 # 3. no attack, so no wrack

## An extra attack, from an item or effect, that doesn't disturb the normal attack rhythm.
func bonus_attack(enemy: BattleUnit) -> int:
	var timer := _attack_timer
	var total := _attack_cooldown_total
	var level := attack_now(enemy)
	_attack_timer = timer
	_attack_cooldown_total = total
	return level

## The damage type of the last hit any unit took. Damage reports (record_damage) come
## right after take_damage, so the damage meter reads this to sort damage by type.
static var last_damage_type: int = Stats.DamageType.MIGHT

func take_damage(amount: float, wrack_level: int = 0, damage_type: int = Stats.DamageType.MIGHT,
		ignore_ward: bool = false, attacker: BattleUnit = null) -> float:
	if not alive:
		return 0.0
	last_damage_type = damage_type
	if CombatRng.randf() < get_dodge_chance():
		show_float_text("Dodge", DODGE_COLOR)
		for status in statuses.duplicate():
			status.on_dodge(self)
		return 0.0   # nothing dealt: no meter credit, no lifesteal, no charge from damage
	# Wards come first. Shields and other effects apply to what's left.
	if not ignore_ward:
		var ward := get_stat(Stats.ward_stat_for(damage_type))
		if attacker != null:
			for status in attacker.statuses:
				ward = status.modify_target_ward(attacker, self, ward, wrack_level)
		amount *= Stats.ward_multiplier(ward)
	if attacker != null:
		for status in attacker.statuses:
			amount = status.modify_damage_dealt(attacker, self, amount)
	incoming_attacker = attacker
	incoming_damage_type = damage_type
	incoming_is_hit = true
	incoming_wrack_level = wrack_level
	var dealt := _apply_damage(amount, Stats.damage_color(damage_type, wrack_level), wrack_level, true)
	incoming_attacker = null
	return dealt

## Damage that has already been through wards, such as damage released over time.
## Shields and other statuses still apply. Leave show_numbers off for small, frequent
## amounts so they don't spam damage numbers.
func take_warded_damage(amount: float, show_numbers: bool = false, damage_type: int = Stats.DamageType.MIGHT) -> float:
	if not alive:
		return 0.0
	incoming_attacker = null
	incoming_damage_type = damage_type
	incoming_is_hit = false
	incoming_wrack_level = 0
	return _apply_damage(amount, Stats.damage_color(damage_type), 0, show_numbers)

## The number color of the hit currently being processed, for statuses that show their
## own numbers (like Bescard's held damage). Only meaningful during modify_incoming_damage.
var incoming_color: Color = Color.WHITE
## Details of the hit currently being processed, for statuses that care. Only
## meaningful during modify_incoming_damage.
var incoming_attacker: BattleUnit = null      # the attacker, for attacks; null otherwise
var incoming_damage_type: int = Stats.DamageType.MIGHT
var incoming_is_hit: bool = false             # false for damage over time and held damage
var incoming_wrack_level: int = 0

func _apply_damage(amount: float, number_color: Color, wrack_level: int, show_numbers: bool) -> float:
	incoming_color = number_color
	var dealt := minf(amount, health + get_shield())
	var shield_before := get_shield()
	# Health left once held damage lands, measured before any status holds this hit, so
	# a held hit still flashes.
	var effective_before := health - get_pending_damage()
	for status in statuses.duplicate():
		amount = status.modify_incoming_damage(self, amount)
	if show_numbers:
		var absorbed := shield_before - get_shield()
		if absorbed > 0.0:
			_spawn_damage_number(absorbed, SHIELD_COLOR)
		if amount > 0.0:
			_spawn_damage_number(minf(amount, health), number_color, wrack_level)
	health -= amount
	_update_health_bar()
	_update_pending_bar()
	if show_numbers:
		_flash_health_loss(effective_before, health - get_pending_damage())
	if health <= 0.0:
		_die()
	return dealt

## Font size for a damage number: bigger for bigger hits, plus a bonus for wracks.
func _damage_font_size(amount: float, wrack_level: int) -> int:
	var t := clampf(amount / DAMAGE_FOR_MAX_FONT, 0.0, 1.0)   # 0 = tiny hit, 1 = huge hit
	t = sqrt(t)   # grows quickly for small hits, then levels off
	var font_size := lerpf(DAMAGE_FONT_MIN, DAMAGE_FONT_MAX, t)
	font_size += WRACK_FONT_BONUS * wrack_level
	return roundi(font_size)

func _spawn_damage_number(amount: float, color: Color = Color.WHITE, wrack_level: int = 0) -> void:
	show_float_text(str(roundi(amount)), color, _damage_font_size(amount, wrack_level))

## Floating text that rises and fades above the unit. Statuses can use this too.
func show_float_text(text: String, color: Color = Color.WHITE, font_size: int = DAMAGE_FONT_MIN) -> void:
	var label := Label.new()
	label.text = text
	label.size = FLOAT_TEXT_BOX
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM   # text sits on the box's bottom edge
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)

	get_tree().current_scene.add_child(label)   # not a child of the unit, so it survives a killing blow
	# Placed by its centre and turned with the view, so it reads upright above the unit
	# even when the battle is being watched turned around.
	label.pivot_offset = FLOAT_TEXT_BOX / 2.0
	label.rotation = view_rotation
	var centre := Vector2(randf_range(-12.0, 12.0), FLOAT_TEXT_BOTTOM - FLOAT_TEXT_BOX.y / 2.0)
	label.global_position = global_position + centre.rotated(view_rotation) - FLOAT_TEXT_BOX / 2.0

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -FLOAT_RISE).rotated(view_rotation), FLOAT_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TIME)
	tween.chain().tween_callback(label.queue_free)

func heal(amount: float, source_id: int = 0, can_wrack: bool = true) -> void:
	if not alive or amount <= 0.0 or health >= max_health:
		return
	if can_wrack:
		var healer := instance_from_id(source_id if source_id != 0 else get_instance_id()) as BattleUnit
		if healer != null:
			amount *= healer.wrack_effect_multiplier(Stats.EffectKind.HEALING, false, self)
	for status in statuses:
		amount = status.modify_healing_received(self, amount)
	if amount <= 0.0:
		return
	var healed := minf(amount, max_health - health)
	health += healed
	_update_health_bar()
	var healer_id := source_id if source_id != 0 else get_instance_id()
	get_tree().call_group("damage_tracker", "record_healing", healer_id, healed)

## Sets current health directly, clamped to max. For summons that come back hurt.
func set_health(amount: float) -> void:
	health = clampf(amount, 0.0, max_health)
	_update_health_bar()

## The unit's current regen per second, after status effects.
func get_health_regen() -> float:
	var regen := health_regen
	for status in statuses:
		regen = status.modify_health_regen(self, regen)
	return maxf(regen, 0.0)

func add_status(status: Status) -> void:
	statuses.append(status)
	status.on_applied(self)
	for other in statuses.duplicate():
		if other != status:
			other.on_status_added(self, status)
	status_added.emit(self, status)


func remove_status(status: Status) -> void:
	if statuses.has(status):
		statuses.erase(status)
		status.on_removed(self)

## Total shield from all statuses.
## Damage this unit has taken but not lost yet, summed over its statuses.
func get_pending_damage() -> float:
	var total := 0.0
	for status in statuses:
		total += status.get_pending_damage(self)
	return total


func get_shield() -> float:
	var total := 0.0
	for status in statuses:
		total += status.get_shield(self)
	return total

## Gives this unit a shield, after anything that changes shields it receives. Credits the
## shielding to `source_id` (the giver's instance id). Returns the shield actually given.
func add_shield(amount: float, duration: float, source_id: int) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var giver := instance_from_id(source_id) as BattleUnit
	if giver != null:
		var level := giver.roll_effect_wrack(Stats.EffectKind.HEALING)
		if level > 0:
			KeepsakeVfx.flourish(self, KeepsakeVfx.SHIELD_WRACK_COLOR)   # silver: a wracked shield
		amount *= giver.effect_wrack_multiplier(level, Stats.EffectKind.HEALING)
	for status in statuses:
		amount = status.modify_shield_received(self, amount)
	if amount <= 0.0:
		return 0.0
	add_status(ShieldStatus.new(amount, duration))
	get_tree().call_group("damage_tracker", "record_shielding", source_id, amount)
	return amount

func clear_statuses() -> void:
	for status in statuses.duplicate():
		remove_status(status)

func _setup_charge_bar() -> void:
	charge_bar = find_child("ChargeBar", true, false) as ProgressBar
	if charge_bar == null:
		push_warning("%s: no ProgressBar named 'ChargeBar' found under this unit." % name)
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = CHARGE_COLOR
	_charge_fill = fill
	charge_bar.add_theme_stylebox_override("fill", fill)
	charge_bar.min_value = 0.0
	charge_bar.max_value = max_charge
	_update_charge_bar()


func _update_charge_bar() -> void:
	if charge_bar == null:
		return
	if _casting and _cast_total > 0.0:
		# Drains from full to empty over the Act time.
		charge_bar.value = max_charge * clampf(_cast_timer / _cast_total, 0.0, 1.0)
	else:
		charge_bar.value = charge
	if _charge_fill != null:
		_charge_fill.bg_color = CASTING_COLOR if (_casting and _cast_total > 0.0) else CHARGE_COLOR

func _ready_to_gambit() -> bool:
	if gambit == null or charge < max_charge:
		return false
	for status in statuses:
		if status.blocks_gambit(self):
			return false
	return gambit.can_use(self)

## Runs the Action and marks any statuses it attached, so they block charge gain.
func _run_gambit() -> void:
	var before := statuses.duplicate()
	gambit.execute(self)
	for status in statuses:
		if not before.has(status):
			status.from_gambit = true

func _begin_gambit() -> void:
	gambit_cast.emit(self)
	charge = 0.0
	_update_charge_bar()
	for status in statuses.duplicate():
		status.on_gambit(self)
	if gambit.cast_time <= 0.0:
		_run_gambit()
		return
	_casting = true
	_cast_timer = gambit.cast_time
	_cast_total = gambit.cast_time
	_update_charge_bar()


func _finish_gambit() -> void:
	_casting = false
	_run_gambit()

## Adds charge, capped at max (no overflow).
func gain_charge(amount: float) -> void:
	if not alive or _casting or _locked_time > 0.0:
		return
	for status in statuses:
		if status.blocks_charge_gain(self):
			return
	amount *= Stats.charge_multiplier(get_stat(Stats.Stat.INSIGHT))
	for status in statuses:
		amount = status.modify_charge_gain(self, amount)
	var before := charge
	charge = minf(charge + amount, max_charge)
	_update_charge_bar()
	if charge > before:
		for status in statuses.duplicate():
			status.on_charge_gained(self, charge - before)

func gain_charge_from_attack(dealt: float, target: BattleUnit = null) -> void:
	if dealt <= 0.0:
		return
	var amount := charge_on_attack
	if target != null:
		for status in target.statuses:
			amount = status.modify_attacker_charge(target, self, amount)
	gain_charge(amount)

## Charge for being hit by an attack: a flat amount plus a share of the damage taken.
func gain_charge_from_hit(damage_taken: float) -> void:
	gain_charge(charge_on_hit + damage_taken * charge_per_damage)

## Sets charge to full, ignoring anything that blocks charge gain. For effects that
## refund a Gambit outright.
func fill_charge() -> void:
	if not alive:
		return
	charge = max_charge
	_update_charge_bar()

## Changes how much charge the Gambit needs, keeping the charge bar in step.
func set_max_charge(value: float) -> void:
	max_charge = maxf(value, 1.0)
	if charge_bar != null:
		charge_bar.max_value = max_charge
	_update_charge_bar()

func _die() -> void:
	alive = false
	remove_from_group("units")
	grid.vacate(cell, self)
	if _moving:
		grid.vacate(_dest_cell, self)
	died.emit(self)
	queue_free()
