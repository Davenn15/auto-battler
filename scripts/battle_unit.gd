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
## Emitted when this unit gains permanent stats (see gain_permanent_stats).
signal permanent_stats_gained(unit: BattleUnit, gains: Dictionary, copied: bool)
## Emitted when this unit is stunned or silenced (Codger's passive watches for it).
signal crowd_controlled(unit: BattleUnit)
## Emitted when this unit CASTS its Gambit: its Charge is full and spent, and its cast time
## begins.
signal gambit_cast(unit: BattleUnit)
## Emitted when this unit PLAYS its Gambit: its cast time is over and the Gambit starts
## (just before it runs). With no cast time, right after gambit_cast.
signal gambit_played(unit: BattleUnit)

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
static func team_color(for_team: int) -> Color:
	var shown := (3 - for_team) if swap_team_colors and (for_team == 1 or for_team == 2) else for_team
	return TEAM_COLORS.get(shown, Color.GRAY)

## Keepsakes this unit has equipped, at most MAX_KEEPSAKES.
var keepsakes: Array[Keepsake] = []

const HEALTH_TICK_INTERVAL := 200.0   # one line per this much max health
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
## A target given up on as unreachable is skipped for this long (unless it's the only one
## left), so the unit doesn't swap straight back to it and get stuck again.
const BLOCKED_MEMORY := 3.0
var _blocked_targets := {}   # instance id -> seconds left
## Seconds a unit waits for an ally standing in its way to move before walking around it.
const ALLY_WAIT := 0.5
var _ally_wait := 0.0
## A unit that steps back into the cell it just left this many times within REVERSAL_WINDOW
## seconds is going back and forth: it gives up on its target as unreachable.
const MAX_REVERSALS := 2
const REVERSAL_WINDOW := 3.0
var _left_cell := Vector2i(-9999, -9999)   # the cell its last step left
var _reversals := 0
var _last_reversal := -INF
## Ranged units (attack range over 1) take their first step this long after combat starts,
## so melee units lead the charge.
const RANGED_START_DELAY := 0.3
var _combat_time := 0.0
## True once a step has passed its halfway point: the unit has given up its old cell and
## `cell` is already the one it's stepping into.
var _step_switched := false

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

const DAMAGE_FONT_MIN := 5.6        # font size for the smallest hits
const DAMAGE_FONT_MAX := 17.6        # font size for hits at or above DAMAGE_FOR_MAX_FONT
const DAMAGE_FOR_MAX_FONT := 400.0   # damage that reaches the biggest size
const WRACK_FONT_BONUS := 1.6        # each wrack level makes the number this much bigger again
const FLOAT_TEXT_FONT := 7           # font size for floating words ("Overdrive", "Revived", ...)
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
## Health about to come back (delayed heals): the team color, darkened.
const PENDING_HEAL_DARKEN := 0.4
var pending_heal_bar: ColorRect

## Badge color for the first and second choice at level 1. Shared by every unit.
const PATH_COLORS: Array[Color] = [Color(0.94, 0.55, 0.16), Color(0.18, 0.72, 0.69)]   # orange, teal
## How far a level-2 badge is shaded from its path color: lighter for the first
## follow-up, darker for the second.
const FOLLOW_UP_SHADE := 0.4

const KEEPSAKE_ICON_SIZE := 6.0   # pixels, square: the item icons just above the plate
## The icons' size while the unit is selected in the info panel, so they can be read and
## hovered (see UnitInfoPanel).
const KEEPSAKE_FOCUS_SIZE := 13.0
const KEEPSAKE_FOCUS_GAP := 2.0

# ---------- The status plate ----------
# Health, Charge, the attack wind-up, upgrade pips and the Ascension diamond sit on one
# small dark plate above the unit, with the Keepsake icons just above it (see _layout_plate).
const PLATE_WIDTH := 44.0     # well under the hex spacing, so neighbours' plates never touch
const PLATE_BOTTOM := -28.0   # the plate's bottom edge, from the unit's centre
const PLATE_PAD := 1.0        # inside the plate's edge
const PLATE_GAP := 1.0        # between the rows
const HEALTH_HEIGHT := 4.0
const CHARGE_HEIGHT := 2.0
const ATTACK_HEIGHT := 1.0
const TIMER_HEIGHT := 2.0     # each extra timer bar (COLUMN's weapons)
const PIP_SIZE := Vector2(3, 3)   # one upgrade pip in the plate's left tab
const PLATE_COLOR := Color(0.08, 0.08, 0.1, 0.75)
const PLATE_BORDER := Color(0.35, 0.35, 0.4)
var _plate: Panel



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
## Health this unit has lost to damage this combat (after wards and shields). M-PATH links
## to the ally with the most.
var damage_taken: float = 0.0

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
## Summons normally don't cast. True keeps the summon's own data Gambit (GATE.W(A)'s Gatelings).
var summon_keeps_gambit: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()
		return
	
	rotation = view_rotation
	add_to_group("units")
	add_to_group("damage_tracker")   # hears every damage report and keeps its own total
	_setup_melee_motion()

	grid = get_tree().get_first_node_in_group("battle_grid") as BattleGrid
	if grid == null:
		push_error("BattleUnit needs a BattleGrid in the scene.")
		return

	_apply_data()
	health = max_health
	_setup_health_bar()
	
	_setup_upgrade_badges()
	_setup_keepsake_icons()
	_setup_ascension_marker()
	update_glory_badge()
	
	charge = starting_charge
	_setup_charge_bar()
	
	_setup_attack_bar()
	_layout_plate()

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
## The army's Ascensions (match Encounters). Set before the unit enters the tree.
var ascensions: Array[Ascension] = []

# ---------- Gains that last the rest of the match (Codger B) ----------
## Stats this unit has gained for the rest of the match, {Stats.Stat: amount}, from its
## ArmyUnit. Added to its base stats. Set before the unit enters the tree.
var match_stats: Dictionary = {}
## Stacks of Glory from earlier fights: each raises its base max health, attributes and Wards by
## GLORY_SHARE. Set before the unit enters the tree.
var glory: int = 0
## What this fight added to them, written back to its ArmyUnit afterwards (real fights
## only; see ArmySpawner.collect_match_gains).
var match_gains: Dictionary = {}
var glory_gained: int = 0
const GLORY_SHARE := 0.05
const GLORY_STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY,
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]
## Base stats before Glory, so Glory gained mid-fight adds the same 5% of them.
var _base_before_glory: Dictionary = {}
## Base max health before Glory (and before Keepsakes and Ascensions), for the same reason.
var _base_health_before_glory := 0.0


## Gains `amount` of `stat` for the rest of the match: now (a permanent stat gain, so
## Lordred A and the like see it) and in every later fight.
func gain_match_stat(stat: Stats.Stat, amount: float) -> void:
	match_gains[stat] = match_gains.get(stat, 0.0) + amount
	add_status(PermanentStatStatus.new(stat, amount))


## Glory a unit can gain per combat, before statuses change it (Status.modify_glory_cap).
const GLORY_CAP := 1


## How many Glory stacks this unit can still gain this combat counts against.
func glory_cap() -> int:
	var cap := GLORY_CAP
	for status in statuses:
		cap = status.modify_glory_cap(self, cap)
	return maxi(cap, 0)


## Gains a stack of Glory for the rest of the match: now and in every later fight. Returns
## false if it's already gained as many as it can this combat.
func gain_glory() -> bool:
	if glory_gained >= glory_cap():
		return false
	glory_gained += 1
	var gains := {}
	for stat in GLORY_STATS:
		gains[stat] = _base_before_glory.get(stat, 0.0) * GLORY_SHARE
	for stat in gains:
		add_status(PermanentStatStatus.new(stat, gains[stat]))
	# Max health too: gaining it heals by the same amount.
	var health_gain := _base_health_before_glory * GLORY_SHARE
	if health_gain > 0.0:
		max_health += health_gain
		health = minf(health + health_gain, max_health)
		if health_bar != null:
			health_bar.max_value = max_health
		_update_health_bar()
		_update_health_ticks()
	show_float_text("Glory!", Color(1.0, 0.85, 0.35))
	KeepsakeVfx.glory_flourish(self)
	update_glory_badge()
	for status in statuses.duplicate():
		status.on_glory_gained(self)
	return true


## The Glory badge: every stack the unit has (earlier fights and this one), dimmed once it
## can't gain more this combat.
func update_glory_badge() -> void:
	KeepsakeVfx.glory_badge(self, glory + glory_gained, active and glory_gained >= glory_cap())

## Copies stats from the UnitData resource, if one is assigned.
func _apply_data() -> void:
	if data == null:
		return
	var chosen := get_chosen_upgrades()
	var level := chosen.size()
	_base_health_before_glory = data.max_health * Stats.upgrade_health_multiplier(level) \
			* Stats.tier_health_multiplier(data.tier) * Stats.buff_health_multiplier(buffs)
	max_health = _base_health_before_glory * (1.0 + GLORY_SHARE * glory)   # Glory: +5% per stack
	for keepsake in keepsakes:
		max_health += keepsake.health
	for ascension in ascensions:
		if ascension.applies_to(data):
			max_health += ascension.health
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
	# Gains kept from earlier fights this match: stats first, then Glory on top of them.
	for stat in match_stats:
		base_stats[stat] = base_stats.get(stat, 0.0) + match_stats[stat]
	_base_before_glory = base_stats.duplicate()
	if glory > 0:
		for stat in GLORY_STATS:
			base_stats[stat] *= 1.0 + GLORY_SHARE * glory
	attack_damage_type = data.attack_damage_type
	if data.sprite != null and sprite != null:
		sprite.texture = data.sprite
	if is_summon:
		max_health = _summon_max_health
		base_stats = _summon_stats
		if not summon_keeps_gambit:
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
	_setup_pending_heal_bar()
	_setup_shield_bar()


func _update_health_bar() -> void:
	if SimMode.active:
		return   # lean sim mode: nothing is watching
	if health_bar != null:
		health_bar.value = maxf(health, 0.0)
	_update_health_ticks()

## The health bar's tick lines (see HealthTicks), or null.
var _health_ticks: HealthTicks = null
## A leftover section at the bar's end narrower than this many screen pixels gets no tick
## of its own: it would read as a doubled line, not as health.
const HEALTH_TICK_MIN_END := 3.0

## Thin black lines across the health bar, one per HEALTH_TICK_INTERVAL of max health.
func _setup_health_ticks() -> void:
	if health_bar == null or max_health <= 0.0:
		return
	_health_ticks = HealthTicks.new()
	_health_ticks.unit = self
	_health_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar.add_child(_health_ticks)


func _update_health_ticks() -> void:
	if _health_ticks != null and is_instance_valid(_health_ticks):
		_health_ticks.queue_redraw()


## The tick lines, drawn on the screen's real pixel grid. The game is stretched by a
## fraction to fit the window, so lines placed at exact fractions of the bar land on 1 or
## 2 pixels and the sections between them come out a pixel wider or narrower at random.
## Here every section in a bar is the same whole number of screen pixels and each tick is
## exactly one pixel wide. Ticks show up to the unit's current health.
class HealthTicks extends Control:
	var unit   # BattleUnit; untyped so a freed one is ignored

	func _ready() -> void:
		set_notify_transform(true)   # redraw as the unit moves: its pixel grid shifts

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(unit) or unit.max_health <= 0.0 or size.x <= 0.0:
			return
		# Local -> screen pixels, and back.
		var to_screen: Transform2D = get_viewport().get_final_transform() * get_global_transform_with_canvas()
		var to_local := to_screen.affine_inverse()
		var left: Vector2 = to_screen * Vector2.ZERO
		var right: Vector2 = to_screen * Vector2(size.x, 0.0)
		var width := absf(right.x - left.x)
		var direction := signf(right.x - left.x)   # -1 when the battle is watched turned around
		var section := maxf(roundf(width * BattleUnit.HEALTH_TICK_INTERVAL / unit.max_health), 2.0)
		var start := roundf(left.x)
		var top: Vector2 = to_screen * Vector2(0.0, 0.0)
		var bottom: Vector2 = to_screen * Vector2(0.0, size.y)
		var i := 1
		while true:
			var x := start + direction * section * i
			var from_end := (right.x - x) * direction
			if from_end < BattleUnit.HEALTH_TICK_MIN_END or i * BattleUnit.HEALTH_TICK_INTERVAL > unit.health:
				break
			# A one-pixel column: from the pixel's left edge to its right edge, in local units.
			var a: Vector2 = to_local * Vector2(x, top.y)
			var b: Vector2 = to_local * Vector2(x + 1.0, bottom.y)
			draw_rect(Rect2(Vector2(minf(a.x, b.x), 0.0), Vector2(absf(b.x - a.x), size.y)), Color.BLACK)
			i += 1


func _setup_pending_bar() -> void:
	pending_bar = ColorRect.new()
	pending_bar.color = PENDING_COLOR
	pending_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pending_bar.visible = false
	health_bar.add_child(pending_bar)   # child of the health bar, so it draws on top of it


## Darkens the end of the health bar by the damage the unit is still due to take.
func _update_pending_bar() -> void:
	if SimMode.active:
		return   # lean sim mode: nothing is watching
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


func _setup_pending_heal_bar() -> void:
	pending_heal_bar = ColorRect.new()
	pending_heal_bar.color = team_color(team).darkened(PENDING_HEAL_DARKEN)
	pending_heal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pending_heal_bar.visible = false
	health_bar.add_child(pending_heal_bar)


## Shows the healing the unit is still due (delayed heals) as a darker stretch right after
## its current health, up to max health.
func _update_pending_heal_bar() -> void:
	if SimMode.active:
		return   # lean sim mode: nothing is watching
	if pending_heal_bar == null or health_bar == null or max_health <= 0.0:
		return
	var coming := minf(get_pending_healing(), max_health - maxf(health, 0.0))
	if coming <= 0.0 or not alive:
		pending_heal_bar.visible = false
		return
	var width := health_bar.size.x
	var start_frac := maxf(health, 0.0) / max_health
	pending_heal_bar.position = Vector2(start_frac * width, 0.0)
	pending_heal_bar.size = Vector2(coming / max_health * width, health_bar.size.y)
	pending_heal_bar.visible = true


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
	if SimMode.active:
		return   # lean sim mode: nothing is watching
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
	if SimMode.active:
		return   # lean sim mode: nothing is watching
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


## The healing flash: the green twin of the damage flash. The part of the health bar a heal
## just filled flashes green, then fades. Heals (Regeneration included) landing within
## DAMAGE_FLASH_WINDOW of the first share one flash, so a stream of small heals reads as one.
const HEAL_FLASH_COLOR := Color(0.4, 1.0, 0.5)
var _heal_flash: ColorRect
var _heal_flash_collecting := false
var _heal_flash_low: float    # health when the current healing flash started
var _heal_flash_top: float    # highest health since then

func _flash_health_gain(from_health: float, to_health: float) -> void:
	if SimMode.active:
		return   # lean sim mode: nothing is watching
	if health_bar == null or max_health <= 0.0 or to_health <= from_health:
		return
	if not _heal_flash_collecting or not is_instance_valid(_heal_flash):
		_heal_flash = ColorRect.new()
		_heal_flash.color = HEAL_FLASH_COLOR
		_heal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_bar.add_child(_heal_flash)   # a child of the bar, so it draws on top of it
		_heal_flash_low = from_health
		_heal_flash_top = from_health
		_heal_flash_collecting = true
		var flash := _heal_flash
		var tween := flash.create_tween()
		tween.tween_interval(DAMAGE_FLASH_WINDOW)
		tween.tween_callback(func(): _heal_flash_collecting = false)
		tween.tween_property(flash, "modulate:a", 0.0, DAMAGE_FLASH_TIME)
		tween.tween_callback(flash.queue_free)
	_heal_flash_top = maxf(_heal_flash_top, to_health)
	var width := health_bar.size.x
	var start := clampf(_heal_flash_low, 0.0, max_health) / max_health
	var end := clampf(_heal_flash_top, 0.0, max_health) / max_health
	_heal_flash.position = Vector2(start * width, 0.0)
	_heal_flash.size = Vector2((end - start) * width, health_bar.size.y)

var _badges: VBoxContainer

## Small pips in the plate's left tab, one per upgrade taken, top to bottom. How many =
## level; colors = which path. Safe to call again if the upgrades change.
func _setup_upgrade_badges() -> void:
	if _badges != null:
		_badges.queue_free()
		_badges = null
	if health_bar == null:
		return
	var chosen := get_chosen_upgrades()
	if chosen.is_empty():
		return
	_badges = VBoxContainer.new()
	_badges.add_theme_constant_override("separation", int(PLATE_GAP))
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for level in chosen.size():
		_badges.add_child(_make_badge(_badge_color(level)))
	health_bar.add_child(_badges)   # a child of the bar, so it moves with it
	_layout_plate()


## A small square of the given color.
func _make_badge(color: Color) -> Control:
	var badge := ColorRect.new()
	badge.color = color
	badge.custom_minimum_size = PIP_SIZE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge


## The color of the badge for upgrade `level` (0 = first upgrade), from the choices
## in upgrade_path.
func _badge_color(level: int) -> Color:
	var path_color := PATH_COLORS[upgrade_path[0] % PATH_COLORS.size()]
	if level == 0:
		return path_color
	# A level past the path is the other final upgrade (Convergence): the other shade.
	var pick: int = upgrade_path[level] if level < upgrade_path.size() else 1 - upgrade_path[-1]
	return path_color.lightened(FOLLOW_UP_SHADE) if pick == 0 else path_color.darkened(FOLLOW_UP_SHADE)


var _keepsake_icons: HBoxContainer
## True while the unit is selected in the info panel: its Keepsake icons are drawn big.
var keepsakes_focused := false


## Draws the Keepsake icons big (selected in the info panel) or small again.
func set_keepsakes_focused(on: bool) -> void:
	if keepsakes_focused == on:
		return
	keepsakes_focused = on
	_setup_keepsake_icons()


func _keepsake_icon_size() -> float:
	return KEEPSAKE_FOCUS_SIZE if keepsakes_focused else KEEPSAKE_ICON_SIZE


func _keepsake_icon_gap() -> float:
	return KEEPSAKE_FOCUS_GAP if keepsakes_focused else PLATE_GAP


## A small icon for each equipped keepsake, in a row just above the plate (bigger, and
## drawn over neighbouring units, while it's selected). Safe to call again whenever the
## keepsakes change.
func _setup_keepsake_icons() -> void:
	if _keepsake_icons != null:
		_keepsake_icons.queue_free()
		_keepsake_icons = null
	if health_bar == null or keepsakes.is_empty():
		return
	_keepsake_icons = HBoxContainer.new()
	_keepsake_icons.add_theme_constant_override("separation", int(_keepsake_icon_gap()))
	_keepsake_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if keepsakes_focused:
		_keepsake_icons.z_index = 30   # over the units around it
	var size := _keepsake_icon_size()
	for keepsake in keepsakes:
		var icon := TextureRect.new()
		icon.texture = keepsake.get_icon()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.custom_minimum_size = Vector2(size, size)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_keepsake_icons.add_child(icon)
	health_bar.add_child(_keepsake_icons)   # a child of the bar, so it moves with it
	_layout_plate()

## Small diamonds on the plate's top-left corner, one per kind of unit Ascension the unit
## has, so its buffs read at a glance on the board: white for a Neutral pick-unit one, the
## faction's colour for a faction pick-unit one, green for one made for this unit
## (Affected Units), and split purple and blue for Convergence.
const ASCENSION_NEUTRAL_COLOR := Color(0.94, 0.94, 0.96)
const ASCENSION_UNIT_COLOR := Color(0.37, 0.88, 0.54)
const ASCENSION_CONVERGE_LEFT := Color(0.69, 0.49, 1.0)
const ASCENSION_CONVERGE_RIGHT := Color(0.49, 0.78, 1.0)
const ASCENSION_MARKER_SPACING := 5.5
const ASCENSION_MARKER_POINTS := [Vector2(0, -3), Vector2(2.3, 0), Vector2(0, 3), Vector2(-2.3, 0)]
## How far above the plate's top edge the diamonds sit (their centres), so they cover less of the bar.
const ASCENSION_MARKER_RAISE := 2.5

enum AscensionKind { NEUTRAL_PICK, FACTION_PICK, UNIT, CONVERGENCE }
## The faction of its faction pick-unit Ascension (for that diamond's colour).
var _faction_pick_faction := ""


## The kinds of unit Ascension this unit has, in a fixed order (see AscensionKind).
func _ascension_kinds() -> Array:
	var kinds := {}
	for ascension in ascensions:
		if ascension.grants_other_final_upgrade:
			kinds[AscensionKind.CONVERGENCE] = true
		elif ascension.is_chosen():
			if ascension.is_neutral():
				kinds[AscensionKind.NEUTRAL_PICK] = true
			else:
				kinds[AscensionKind.FACTION_PICK] = true
				_faction_pick_faction = ascension.faction_name()
		elif not ascension.affected_units.is_empty() and ascension.affected_units.has(data):
			kinds[AscensionKind.UNIT] = true
	var ordered := kinds.keys()
	ordered.sort()
	return ordered


func _setup_ascension_marker() -> void:
	if health_bar == null:
		return
	var kinds := _ascension_kinds()
	if kinds.is_empty():
		return
	var marker := Node2D.new()
	marker.name = "AscensionMarker"
	for i in kinds.size():
		var diamond := _ascension_diamond(kinds[i])
		diamond.position = Vector2(i * ASCENSION_MARKER_SPACING, 0)
		marker.add_child(diamond)
	health_bar.add_child(marker)
	_layout_plate()


## One kind's diamond, outlined in black.
func _ascension_diamond(kind: int) -> Node2D:
	var diamond := Node2D.new()
	var points := PackedVector2Array(ASCENSION_MARKER_POINTS)
	if kind == AscensionKind.CONVERGENCE:   # two halves
		for half in [[ASCENSION_CONVERGE_LEFT, [points[0], points[2], points[3]]], [ASCENSION_CONVERGE_RIGHT, [points[0], points[1], points[2]]]]:
			var piece := Polygon2D.new()
			piece.polygon = PackedVector2Array(half[1])
			piece.color = half[0]
			piece.antialiased = true
			diamond.add_child(piece)
	else:
		var fill := Polygon2D.new()
		fill.polygon = points
		fill.color = _ascension_kind_color(kind)
		fill.antialiased = true
		diamond.add_child(fill)
	var outline := Line2D.new()
	outline.points = PackedVector2Array(ASCENSION_MARKER_POINTS + [ASCENSION_MARKER_POINTS[0]])
	outline.width = 1.0
	outline.default_color = Color(0, 0, 0, 0.8)
	outline.antialiased = true   # smoothed, so every diamond looks the same at any window scale
	diamond.add_child(outline)
	return diamond


func _ascension_kind_color(kind: int) -> Color:
	match kind:
		AscensionKind.NEUTRAL_PICK:
			return ASCENSION_NEUTRAL_COLOR
		AscensionKind.FACTION_PICK:
			return RoundTrack.FACTION_COLORS.get(_faction_pick_faction, ASCENSION_NEUTRAL_COLOR)
		AscensionKind.UNIT:
			return ASCENSION_UNIT_COLOR
	return ASCENSION_NEUTRAL_COLOR

## Lays out the status plate: a dark panel behind everything, an upgrade-pip tab on its
## left (when the unit has upgrades), then Health, Charge and the attack wind-up stacked,
## the Keepsake icons in a row just above the plate (when it has any), and the Ascension diamonds
## on the top-left corner. Everything hangs off the health bar, so it moves, turns and hides
## with it. Safe to call again whenever upgrades, items or Ascensions change.
## Extra height the plate floats at, e.g. FRAME looming over an ally in the same cell, so
## the two plates don't sit on top of each other. Change it through set_plate_lift.
var plate_lift := 0.0

func set_plate_lift(lift: float) -> void:
	plate_lift = lift
	_layout_plate()

func _layout_plate() -> void:
	if health_bar == null:
		return
	var tab := (PIP_SIZE.x + PLATE_GAP) if _badges != null and is_instance_valid(_badges) else 0.0
	var width := PLATE_WIDTH - PLATE_PAD * 2.0 - tab
	health_bar.size = Vector2(width, HEALTH_HEIGHT)
	var y := HEALTH_HEIGHT + PLATE_GAP
	if charge_bar != null and charge_bar.visible:
		charge_bar.position = Vector2(0, y)
		charge_bar.size = Vector2(width, CHARGE_HEIGHT)
		y += CHARGE_HEIGHT + PLATE_GAP
	if attack_bar != null and attack_bar.visible:
		attack_bar.position = Vector2(0, y)
		attack_bar.size = Vector2(width, ATTACK_HEIGHT)
		y += ATTACK_HEIGHT
	for bar in _timer_bars:
		y += PLATE_GAP
		bar.position = Vector2(0, y)
		bar.size = Vector2(width, TIMER_HEIGHT)
		y += TIMER_HEIGHT
	if _badges != null and is_instance_valid(_badges):
		_badges.position = Vector2(-tab, 0)
	var marker := health_bar.get_node_or_null("AscensionMarker")
	if marker != null:
		marker.position = Vector2(-PLATE_PAD - tab, -PLATE_PAD - ASCENSION_MARKER_RAISE)
	if _plate == null:
		_plate = Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = PLATE_COLOR
		style.border_color = PLATE_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		_plate.add_theme_stylebox_override("panel", style)
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.show_behind_parent = true   # behind the health bar and everything on it
		health_bar.add_child(_plate)
	_plate.position = Vector2(-PLATE_PAD - tab, -PLATE_PAD)
	_plate.size = Vector2(PLATE_WIDTH, y + PLATE_PAD * 2.0)
	health_bar.position = Vector2(-PLATE_WIDTH / 2.0 + PLATE_PAD + tab, PLATE_BOTTOM - _plate.size.y + PLATE_PAD - plate_lift)
	if _keepsake_icons != null and is_instance_valid(_keepsake_icons):   # centred just above the plate
		var count := _keepsake_icons.get_child_count()
		var row := count * _keepsake_icon_size() + maxf(count - 1, 0) * _keepsake_icon_gap()
		_keepsake_icons.position = Vector2(_plate.position.x + (PLATE_WIDTH - row) / 2.0,
				-PLATE_PAD - 1.0 - _keepsake_icon_size())

## Which keepsake badge is at `world` (with a little slack, as they're small), or -1.
func keepsake_index_at(world: Vector2, slack: float = 3.0) -> int:
	if _keepsake_icons == null or not is_instance_valid(_keepsake_icons):
		return -1
	var icons := _keepsake_icons.get_children()
	for i in icons.size():
		if (icons[i] as Control).get_global_rect().grow(slack).has_point(world):
			return i
	return -1

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

## A summon joining the fight takes its army's Ascensions (their stats are added by
## start_combat). Their Health only needs adding to summons rebuilt as a full unit (revives,
## copies): ones sized from a source's health already include it.
func give_ascensions(list: Array[Ascension]) -> void:
	list = list.filter(func(a): return not a.is_chosen())   # those belong to one unit only
	if list.is_empty() or not ascensions.is_empty():
		return
	ascensions.assign(list)
	if _summon_stats.is_empty():   # built as a normal unit, then made a summon
		var bonus := 0.0
		for ascension in ascensions:
			if ascension.applies_to(data):
				bonus += ascension.health
		if bonus != 0.0:
			resize_health(max_health + bonus, health + bonus)

## The id this unit's damage is credited to on the damage meter: its summoner for
## summons, itself otherwise.
func get_credit_id() -> int:
	return _summoner_id if is_summon else get_instance_id()

## The id of the unit that summoned this one (0 if it isn't a summon).
func get_summoner_id() -> int:
	return _summoner_id if is_summon else 0

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
	if ascensions.any(func(a): return a.grants_other_final_upgrade):   # Convergence
		chosen.append_array(other_final_upgrades(data, upgrade_path))
	return chosen


## The final upgrades on `path`'s last step that weren't picked (e.g. A2 for A1). Empty
## if the path isn't at a final step, or that step has no other choice.
static func other_final_upgrades(unit_data: UnitData, path: Array[int]) -> Array[Upgrade]:
	var others: Array[Upgrade] = []
	if unit_data == null or path.is_empty():
		return others
	var choices := unit_data.upgrades
	for i in path.size() - 1:
		if path[i] < 0 or path[i] >= choices.size():
			return others
		choices = choices[path[i]].next_choices
	var last: Upgrade = choices[path[-1]] if path[-1] >= 0 and path[-1] < choices.size() else null
	if last == null or not last.next_choices.is_empty():
		return others   # not at the final step
	for i in choices.size():
		if i != path[-1]:
			others.append(choices[i])
	return others


func get_upgrade_level() -> int:
	return get_chosen_upgrades().size()

## Every damage source reports here (through the "damage_tracker" group). Vampirism heals
## from it unless `lifesteal` is false (damage over time like Mono-Virus).
func record_damage(unit_id: int, amount: float, lifesteal: bool = true) -> void:
	if unit_id == get_instance_id():
		damage_dealt += amount
		var vampirism := get_stat(Stats.Stat.VAMPIRISM)
		if lifesteal and vampirism > 0.0 and amount > 0.0:
			heal(amount * vampirism)
		var hit_target := _direct_target_for(amount)
		if hit_target != null:
			for status in statuses.duplicate():
				status.on_direct_damage_dealt(self, hit_target, amount)


## The latest direct damage (take_damage with numbers shown), so record_damage, which
## every source calls right after dealing damage, can tell direct damage from damage over
## time and knows who took it. Cleared by damage over time and once it's been used.
static var _direct_target_id := 0
static var _direct_amount := -1.0

static func _note_direct_damage(target: BattleUnit, dealt: float, direct: bool) -> void:
	_direct_target_id = target.get_instance_id() if direct else 0
	_direct_amount = dealt if direct else -1.0

static func _direct_target_for(amount: float) -> BattleUnit:
	if _direct_target_id == 0 or amount <= 0.0 or not is_equal_approx(amount, _direct_amount):
		return null
	var target := instance_from_id(_direct_target_id) as BattleUnit
	_direct_target_id = 0
	_direct_amount = -1.0
	return target


func record_healing(_unit_id: int, _amount: float) -> void:
	pass


func record_shielding(_unit_id: int, _amount: float) -> void:
	pass

## Equips a keepsake if there's a free slot. Returns false if the unit is full.
## How many Keepsakes it can carry: MAX_KEEPSAKES plus any extra slots from its Ascensions.
func max_keepsakes() -> int:
	var slots := MAX_KEEPSAKES
	for ascension in ascensions:
		if ascension != null and ascension.applies_to(data):
			slots += ascension.keepsake_slots
	return slots


func equip(keepsake: Keepsake) -> bool:
	if keepsake == null or keepsakes.size() >= max_keepsakes():
		return false
	if not Keepsake.allowed_with(keepsake, keepsakes):
		return false   # the universal rule: never two of the same completed Keepsake
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
## Before a fight: rebuilds the unit after its upgrades or Ascensions were changed (the
## random battle's test panel): stats, health, upgrade pips, the Ascension diamond and
## the plate. Starts it at full health.
func refresh_setup() -> void:
	_keepsakes_changed()
	health = max_health
	_update_health_bar()
	_setup_upgrade_badges()
	var marker := health_bar.get_node_or_null("AscensionMarker") if health_bar != null else null
	if marker != null:
		marker.free()
	_setup_ascension_marker()
	_layout_plate()


func _keepsakes_changed() -> void:
	var had := max_health
	_apply_data()
	_refresh_after_keepsakes(had)


## Mid-combat: puts `added` on the unit with its stats and effect, taking `replacing` off
## first if given (a Shard being combined into `added`). Unlike equip(), it doesn't rebuild
## the unit, which would undo things set up at the start of the fight. Either may be null.
## For temporary items, such as VE5TIBULE's Shards.
func swap_keepsake_in_combat(added: Keepsake, replacing: Keepsake = null) -> void:
	var had := max_health
	if replacing != null and keepsakes.has(replacing):
		keepsakes.erase(replacing)
		max_health -= replacing.health
		for status in statuses.duplicate():
			if status is KeepsakeStatsStatus and status.keepsake == replacing:
				remove_status(status)
				break
		for i in _keepsake_effect_statuses.size():
			if _keepsake_effect_statuses[i][0] == replacing:
				for status in _keepsake_effect_statuses[i][1]:
					remove_status(status)
				_keepsake_effect_statuses.remove_at(i)
				break
	if added != null:
		keepsakes.append(added)
		max_health += added.health
		if active:
			add_status(KeepsakeStatsStatus.new(added))
			_start_keepsake_effect(added)
	_refresh_after_keepsakes(had)


## [keepsake, statuses its effect added], so a keepsake taken off mid-combat takes its
## effect with it.
var _keepsake_effect_statuses: Array = []

func _start_keepsake_effect(keepsake: Keepsake) -> void:
	if keepsake.effect == null:
		return
	var before := statuses.duplicate()
	keepsake.effect.on_battle_start(self)
	var added: Array[Status] = []
	for status in statuses:
		if not before.has(status):
			added.append(status)
	_keepsake_effect_statuses.append([keepsake, added])


## Mid-combat: sets max health and health directly and redraws the bar. For effects that
## resize a unit, such as REPL\K8R splitting itself.
func resize_health(new_max: float, new_health: float) -> void:
	max_health = maxf(new_max, 1.0)
	_refresh_after_keepsakes(max_health)
	set_health(clampf(new_health, 1.0, max_health))


func _refresh_after_keepsakes(had: float) -> void:
	health = clampf(health + max_health - had, 1.0, max_health)
	if health_bar != null:
		health_bar.max_value = max_health
		_update_health_ticks()   # tick lines depend on max health
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
	_rest_sprite_scale = sprite.scale

## True on the planning board after preview_combat_start: the unit carries everything
## combat start gives it, but stays out of combat, and nothing can hurt, heal or charge it.
var previewing := false


## Planning: applies what the start of combat would (passives, Keepsakes and their effects,
## Ascensions), so the planner shows the unit as it will fight: its stats, shields, auras
## and other visuals. The unit stays inactive. Call once every unit is on the board (auras
## look at allies). Combat uses freshly spawned units, so nothing here carries over.
func preview_combat_start() -> void:
	previewing = true
	_apply_battle_start_effects()


func start_combat() -> void:
	previewing = false
	_apply_battle_start_effects()
	_casting = false
	# Safety net: the stored cell must match where the unit is actually standing.
	var actual := grid.world_to_cell(global_position)
	if actual != cell:
		push_warning("%s: stored cell %s doesn't match its position (cell %s). Something placed or moved it without place_at()." % [name, cell, actual])
		if grid.has_cell(actual):
			place_at(actual)
	charge = starting_charge
	_update_charge_bar()
	active = true
	_combat_time = 0.0
	_left_cell = Vector2i(-9999, -9999)
	_reversals = 0
	_last_reversal = -INF
	_blocked_targets.clear()
	_ally_wait = 0.0
	_locked_time = 0.0
	_stunned_time = 0.0
	damage_dealt = 0.0
	damage_taken = 0.0



## Everything a unit gains as combat starts: its passives, Keepsakes (stats and effects)
## and Ascensions (stats and effects). Clears what it had first. Grit goes on first, so it
## catches hits before any shield (it does nothing for a unit without Grit).
func _apply_battle_start_effects() -> void:
	clear_statuses()
	add_status(Grit.new())
	for passive in passives:
		passive.on_battle_start(self)
	_keepsake_effect_statuses.clear()
	for keepsake in keepsakes:
		add_status(KeepsakeStatsStatus.new(keepsake))
		_start_keepsake_effect(keepsake)
	for ascension in ascensions:
		if not ascension.applies_to(data):
			continue
		add_status(Ascension.StatsStatus.new(ascension))
		if ascension.effect != null:
			ascension.effect.on_battle_start(self)


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

	if active:
		_rescale_attack_timer()
		_combat_time += delta
		for id in _blocked_targets.keys():
			_blocked_targets[id] -= delta
			if _blocked_targets[id] <= 0.0:
				_blocked_targets.erase(id)
	if _stunned_time > 0.0:
		_stunned_time -= delta   # stunned: no winding up an attack
	elif not _is_channeling():
		_attack_timer = maxf(_attack_timer - delta, 0.0)
	if _stun_swirl != null:
		_stun_swirl.visible = _stunned_time > 0.0
	for status in _with(&"tick").duplicate():
		status.tick(self, delta)
	_update_shield_bar()
	_update_pending_bar()
	_update_pending_heal_bar()
	_update_attack_bar()
	if active:
		heal(get_health_regen() * delta, 0, false)
		var charge_regen := get_charge_regen()
		if charge_regen > 0.0 and gambit != null:
			gain_charge(charge_regen * delta)



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
		# Silence that lands during the cast time pauses it until it ends.
		for status in _with(&"blocks_gambit"):
			if status.blocks_gambit(self):
				_update_charge_bar()
				return
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
	if _ready_to_gambit() and not _finishing_attack():
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
	if is_immobile():
		target = _enemy_in_range()   # can't walk to it: switch to one it can reach, if any
		return
	_start_step()


## True while a status stops the unit from walking (COLUMN and GATE.W(A) never move).
func is_immobile() -> bool:
	for status in _with(&"blocks_movement"):
		if status.blocks_movement(self):
			return true
	return false


## The nearest enemy within attack range, or null.
func _enemy_in_range() -> BattleUnit:
	var best: BattleUnit = null
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not _is_valid_target(unit):
			continue
		var dist := grid.get_distance(cell, unit.cell)
		if dist <= attack_range and (best == null or dist < grid.get_distance(cell, best.cell)):
			best = unit
	return best

## True if the unit could attack `enemy` right now: everything that stops a normal attack
## (inactive, stunned, casting or held by a Gambit, mid-step, an invalid or out-of-range
## target, a status that blocks attacks) stops it. Attack Beams are attacks, so they use
## this too; `except` is the Beam's own status, which blocks the normal attack itself.
func can_attack_now(enemy, except: Status = null) -> bool:
	if not active or not alive or _stunned_time > 0.0 or _is_channeling() or _moving:
		return false
	if not is_instance_valid(enemy) or not _is_valid_target(enemy):
		return false
	if grid.get_distance(cell, enemy.cell) > attack_range:
		return false
	for status in _with(&"blocks_attacks"):
		if status != except and status.blocks_attacks(self):
			return false
	return true

## True while the unit is busy with its Gambit: casting it, or held in place by one
## (dashes, channels, flurries, tosses). Its attack timer doesn't wind up meanwhile.
func _is_channeling() -> bool:
	return _casting or _locked_time > 0.0

## The target that has been within effective range (attack range + RETARGET_SLACK) since
## it was picked. Untyped: it may be freed. Leaving effective range drops that target.
var _reached_target = null

## The first step toward the nearest free cell (fewest steps away) from which this unit
## could hit its target, or the unit's own cell if there's no way there. Enemies block the
## way, and so do allies that are planted (fighting, casting, held or rooted: they won't
## clear out). An ally on the move only blocks it when `allies_block` is true; otherwise
## the path may lead through it and the unit waits for it to move. Ties between equally
## near cells go to the one nearest the unit on screen.
func _next_step_toward_target(allies_block: bool) -> Vector2i:
	var came_from := {cell: cell}
	var frontier: Array[Vector2i] = [cell]
	while not frontier.is_empty():
		var goals: Array[Vector2i] = []
		for c in frontier:
			if c != cell and grid.can_place(c) and grid.get_distance(c, target.cell) <= attack_range:
				goals.append(c)
		if not goals.is_empty():
			var best: Vector2i = goals[0]
			var best_d := INF
			for g in goals:
				var d := global_position.distance_squared_to(grid.cell_to_world(g))
				if d < best_d:
					best_d = d
					best = g
			var step := best
			while came_from[step] != cell:
				step = came_from[step]
			return step
		var next_frontier: Array[Vector2i] = []
		for c in frontier:
			for dir in BattleGrid.DIRECTIONS:
				var n: Vector2i = c + dir
				if came_from.has(n) or not grid.has_cell(n):
					continue
				var occupant := grid.unit_at(n)
				if occupant != null and occupant != self and (occupant.team != team or allies_block or not occupant.is_about_to_move()):
					continue   # can't walk through it
				came_from[n] = c
				next_frontier.append(n)
		frontier = next_frontier
	return cell

func _start_step() -> void:
	if attack_range > 1 and _combat_time < RANGED_START_DELAY:
		return   # melee units lead the charge
	var next := _next_step_toward_target(false)
	if next != cell and grid.is_occupied(next):
		# An ally is in the way. If it's on the move (or about to be), give it a moment to
		# clear out; if it's planted (fighting, casting, can't move), walk around it now.
		var ally := grid.unit_at(next)
		_ally_wait += get_physics_process_delta_time()
		if _ally_wait >= ALLY_WAIT or ally == null or not ally.is_about_to_move():
			next = _next_step_toward_target(true)
		else:
			return
	if next == cell:
		# No free path right now. Keep trying, but give up on this target if it stays unreachable.
		_blocked_time += get_physics_process_delta_time()
		if _blocked_time >= BLOCKED_TARGET_TIMEOUT:
			_give_up_on_target()
		return
	if next == _left_cell:
		# Stepping straight back where it came from: going back and forth?
		if _combat_time - _last_reversal > REVERSAL_WINDOW:
			_reversals = 0
		_reversals += 1
		_last_reversal = _combat_time
		if _reversals >= MAX_REVERSALS:
			_reversals = 0
			_give_up_on_target()
			return
	_blocked_time = 0.0
	_ally_wait = 0.0
	_left_cell = cell
	_dest_cell = next
	_dest_world = grid.cell_to_world(next)
	grid.occupy(next, self)   # reserve the destination immediately
	_step_switched = false
	_moving = true


## The target can't be reached for now: skip it for BLOCKED_MEMORY seconds and pick someone
## else (it's still picked if it's the only one left).
func _give_up_on_target() -> void:
	if _is_valid_target(target):
		_blocked_targets[target.get_instance_id()] = BLOCKED_MEMORY
	target = _choose_target(target)
	_blocked_time = 0.0
	_ally_wait = 0.0


func _continue_step(delta: float) -> void:
	global_position = global_position.move_toward(_dest_world, move_speed * delta)
	# Halfway there, it gives up its old cell, so whoever is waiting behind can follow.
	if not _step_switched and global_position.distance_to(_dest_world) <= grid.cell_spacing() * 0.5:
		_switch_step_cell()
	if global_position.is_equal_approx(_dest_world):
		if not _step_switched:
			_switch_step_cell()
		_moving = false
		if retarget_on_move:
			_retarget_after_step()


## True if this unit is walking, or will take a step soon: it isn't held, casting or rooted,
## and its target is out of reach. A unit waiting behind it can expect the cell to clear.
func is_about_to_move() -> bool:
	if _moving:
		return true
	if not active or _locked_time > 0.0 or _casting or _stunned_time > 0.0 or is_immobile():
		return false
	return _is_valid_target(target) and grid.get_distance(cell, target.cell) > attack_range


func _switch_step_cell() -> void:
	grid.vacate(cell, self)
	cell = _dest_cell
	_step_switched = true


## Test rule: a unit whose attack is at least FINISH_ATTACK_SHARE wound up, with its target
## in range, lands that attack before casting its Gambit. The balance sim can turn it off
## (--no-finish-attack) to compare.
static var finish_attack_before_gambit := true
const FINISH_ATTACK_SHARE := 0.5
## Test rule: casting a Gambit restarts the attack wind-up, so the next attack comes a full
## attack cooldown after the cast. The balance sim can turn it off (--no-gambit-resets-attack).
static var gambit_resets_attack := true


## True while the unit should hold its Gambit to land an attack it has mostly wound up.
func _finishing_attack() -> bool:
	if not finish_attack_before_gambit or _attack_cooldown_total <= 0.0:
		return false
	for status in _with(&"blocks_attacks"):
		if status.blocks_attacks(self):
			return false   # no normal attack is coming
	if not _is_valid_target(target) or grid.get_distance(cell, target.cell) > attack_range:
		return false
	return 1.0 - _attack_timer / _attack_cooldown_total >= FINISH_ATTACK_SHARE


## Test rule: after every step, a unit picks its best target again (the nearest enemy,
## unless a status like a taunt says otherwise) instead of sticking with its old one.
## The balance sim can turn it off (--no-retarget-on-move) to compare.
static var retarget_on_move := true


func _retarget_after_step() -> void:
	var best := _choose_target()
	if best != null and best != target:
		target = best
		_blocked_time = 0.0


## The nearest valid enemy, in hexes. Among equally near enemies: the current target if
## it's one of them (so a unit never flips between them), else the one farthest from its
## own team's back edge (usually its front line), then a random one. Enemies given up on as
## unreachable a moment ago are skipped unless there's no one else.
func _find_nearest_enemy(exclude: BattleUnit = null) -> BattleUnit:
	var nearest := _nearest_enemies(exclude, true)
	if nearest.is_empty():
		nearest = _nearest_enemies(exclude, false)
	if nearest.is_empty():
		return null
	if nearest.has(target):
		return target
	var best_depth := -1
	var deepest: Array = []
	for u in nearest:
		var depth := _depth_from_back_edge(u)
		if depth > best_depth:
			best_depth = depth
			deepest = [u]
		elif depth == best_depth:
			deepest.append(u)
	if deepest.size() == 1:
		return deepest[0]
	# Random, but the same every time for the same fight: tree order can vary, ids don't.
	deepest.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	return CombatRng.pick(deepest)


func _nearest_enemies(exclude: BattleUnit, skip_blocked: bool) -> Array:
	var result: Array = []
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as BattleUnit
		if u == null or u == exclude or not _is_valid_target(u):
			continue
		if skip_blocked and _blocked_targets.has(u.get_instance_id()):
			continue
		var d := grid.get_distance(cell, u.cell)
		if d < best_dist:
			best_dist = d
			result = [u]
		elif d == best_dist:
			result.append(u)
	return result


## Rows between `unit` and its own team's back edge (team 1 holds the bottom rows, team 2
## the top).
func _depth_from_back_edge(unit: BattleUnit) -> int:
	return grid.rows - 1 - unit.cell.y if unit.team == 1 else unit.cell.y

## Who to target next: the nearest enemy, unless a status says otherwise.
func _choose_target(exclude: BattleUnit = null) -> BattleUnit:
	var choice := _find_nearest_enemy(exclude)
	for status in _with(&"modify_target_choice"):
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

## Moves the unit to `dest` against its will (pulled, knocked back): drops any step it was
## taking, then slides there over `time`. Await it to wait for the slide.
func force_move(dest: Vector2i, time: float) -> void:
	if _moving:
		if not _step_switched:
			grid.vacate(_dest_cell, self)   # give up the cell it was stepping into
		_moving = false
		global_position = grid.cell_to_world(cell)
	await dash_to(dest, time)


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
	for status in _with(&"modify_final_stat"):
		value = status.modify_final_stat(self, stat, value)
	if stat == Stats.Stat.MIGHT_WARD or stat == Stats.Stat.INSIGHT_WARD or stat == Stats.Stat.CELERITY_WARD:
		value += maxf(get_stat(Stats.Stat.IMMOVABILITY) - 100.0, 0.0) * Stats.IMMOVABILITY_WARDS   # Immovability over 100
	return maxf(value, 0.0)


## A stat after every status's normal adjustment but before final ones. For statuses
## that turn one stat into another; everything else should use get_stat.
func get_stat_before_final(stat: Stats.Stat) -> float:
	var value: float = base_stats.get(stat, 0.0)
	for status in _with(&"modify_stat"):
		value = status.modify_stat(self, stat, value)
	return value

## Wrack damage against a particular target, after statuses that care who's being hit.
func get_wrack_damage_against(victim: BattleUnit) -> float:
	var value := get_stat(Stats.Stat.WRACK_DAMAGE)
	for status in statuses:
		value = status.modify_wrack_damage(self, victim, value)
	return value

## Aura spent on this unit: its purchase price plus any upgrades.
func get_aura_value() -> int:
	if data == null or is_summon:
		return 0
	return Economy.unit_aura_value(data.tier, upgrade_path.size())   # upgrades bought, not ones from Ascensions


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
	if wrack_level > 0:
		wracked.emit(self)   # Sumpton's Wrack Tally counts these
	if wrack_level >= 3:
		show_float_text("UBER!", Stats.UBER_WRACK_COLOR)
	elif wrack_level == 2:
		show_float_text("Hyper!", Stats.HYPER_WRACK_COLOR)
	var base_damage := Stats.attack_damage(get_stat(Stats.Stat.MIGHT)) + extra_damage
	# Melee or ranged is decided by the range this attack started with: on_attack below may
	# change it for the NEXT attack (Von Carrow's pistol loads a shot on her second swing).
	var ranged := attack_range > 1
	attack_target = enemy
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
	hit_effects = repeat_hit_effects(hit_effects)
	var hit_damage := base_damage * Stats.wrack_multiplier(wrack_level, get_wrack_damage_against(enemy))
	if ranged or projectile != null:
		_fire_projectile(enemy, hit_damage, wrack_level, shot_color, hit_effects, projectile)
		return wrack_level
	_play_melee_swing(enemy.global_position)
	KeepsakeVfx.hit_mark(enemy, (enemy.global_position - global_position).angle(), team_color(team))
	var dealt := enemy.take_damage(hit_damage, wrack_level, get_attack_damage_type(), ignores_wards(), self)
	get_tree().call_group("damage_tracker", "record_damage", get_credit_id(), dealt)
	gain_charge_from_attack(dealt, enemy)
	enemy.gain_charge_from_hit(dealt)
	enemy.notify_attacked(self, dealt)
	notify_attack_hit(enemy, dealt)
	run_hit_effects(hit_effects, enemy, dealt, wrack_level)
	return wrack_level

## The enemy the attack currently being made is aimed at. Set while statuses' on_attack
## runs (an extra attack can aim at someone other than the unit's target).
var attack_target: BattleUnit = null

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

## Any damage `source` deals to `target`, after its statuses change it
## (Status.modify_damage_against). take_damage does this itself when given an attacker;
## damage dealt without one (Gambits, Hit Effects, damage over time...) passes its amount
## through this first. `source` may be the unit, its instance id, or a freed unit.
static func damage_bonus(source, target: BattleUnit, amount: float) -> float:
	if source is int:
		source = instance_from_id(source) if source != 0 else null
	if not is_instance_valid(source) or not source is BattleUnit or not is_instance_valid(target):
		return amount
	for status in source.statuses:
		amount = status.modify_damage_against(source, target, amount)
	return amount


## Gambit damage: every Gambit (and anything a Gambit creates that deals damage: missiles,
## bolts, rings, boomerangs, pools, waves, drones, Focus Beam's ticks) calls this right
## after dealing damage, so `caster`'s statuses hear of it (Status.on_gambit_damage).
## `caster` may be the unit, its instance id, or a freed unit (then nothing happens).
## New Gambits that deal damage should call it too.
static func gambit_damage_dealt(caster, target: BattleUnit, dealt: float) -> void:
	if caster is int:
		caster = instance_from_id(caster)
	if dealt <= 0.0 or not is_instance_valid(caster) or not caster is BattleUnit or not is_instance_valid(target):
		return
	for status in caster.statuses.duplicate():
		status.on_gambit_damage(caster, target, dealt)


## Gambits that affect units (shields, buffs) call this for each unit they affect, so the
## caster's statuses hear of it (Status.on_gambit_target). Lunck's Rally Shield and
## Adoration do; new ally-affecting Gambits should too.
static func gambit_affected(caster, target: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster is BattleUnit or not is_instance_valid(target):
		return
	for status in caster.statuses.duplicate():
		status.on_gambit_target(caster, target)


## `effects` with each one listed again for every extra run this unit's statuses ask for
## (see Status.extra_hit_effect_runs), so they all trigger that many more times on landing.
## Call once per attack, after on_attack.
func repeat_hit_effects(effects: Array[HitEffect]) -> Array[HitEffect]:
	var extra := 0
	for status in statuses.duplicate():
		extra += status.extra_hit_effect_runs(self)
	var result: Array[HitEffect] = effects.duplicate()
	for i in extra:
		result.append_array(effects)
	return result


static func run_hit_effects(effects: Array[HitEffect], hit_target: BattleUnit, dealt: float, wrack_level: int) -> void:
	if dealt <= 0.0:
		return
	for effect in effects:
		effect.apply(hit_target, dealt, wrack_level)

func _fire_projectile(enemy: BattleUnit, hit_damage: float, wrack_level: int, color: Color,
		hit_effects: Array[HitEffect], projectile: Projectile = null) -> void:
	if not is_inside_tree():
		return   # off the board: no shot
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
	KeepsakeVfx.fire_pulse(self, get_attack_cooldown())


## The melee lunge, hit jolt and ranged firing pulse move or scale this node, which sits
## between the unit and its sprite. Nothing else touches it, so effects that move or resize
## the sprite itself (FRAME's stretch, the Chosen's slam lift, Mallet's hop) never fight them.
var melee_motion: Node2D

## Where the sprite sits and how big it is when nothing is animating it. Shots hit the
## sprite at rest (SpriteEdge), so animations never change when a shot lands.
var rest_sprite_position := Vector2.ZERO
var rest_sprite_offset := Vector2.ZERO   # the sprite's drawing offset at rest (a Knock-up lifts it)

var _rest_sprite_scale := Vector2.ZERO   # kept up to date by _update_sprite_size

func rest_sprite_scale() -> Vector2:
	if sprite == null:
		return Vector2.ZERO
	return _rest_sprite_scale if _rest_sprite_scale != Vector2.ZERO else sprite.scale

func _setup_melee_motion() -> void:
	if sprite == null or melee_motion != null:
		return
	rest_sprite_position = sprite.position
	rest_sprite_offset = sprite.offset
	melee_motion = Node2D.new()
	melee_motion.name = "MeleeMotion"
	add_child(melee_motion)
	move_child(melee_motion, sprite.get_index())
	sprite.reparent(melee_motion, false)   # the motion node sits at (0, 0), so nothing shifts

## Set by effects that draw their own swing for an extra attack (Ghost Strike, Mage
## Hunter), so the unit's normal white swing doesn't play on top of it.
var hide_next_swing: bool = false

func _play_melee_swing(target_pos: Vector2) -> void:
	if hide_next_swing:
		return
	var color := Color.WHITE
	for status in statuses:
		color = status.modify_swing_color(self, color)
	var aim := (target_pos - global_position).angle()
	KeepsakeVfx.swing(self, aim, color)
	KeepsakeVfx.lunge(self, aim, get_attack_cooldown())

## Celerity (or anything else changing attack speed) that changes mid-swing applies to the
## attack already winding up: the wind-up keeps how far along it is and finishes at the new
## speed. E.g. halfway through a 2s wind-up, doubling attack speed leaves 0.5s, not 1s.
func _rescale_attack_timer() -> void:
	if _attack_timer <= 0.0 or _attack_cooldown_total <= 0.0:
		return
	var now := get_attack_cooldown()
	if is_equal_approx(now, _attack_cooldown_total):
		return
	_attack_timer *= now / _attack_cooldown_total
	_attack_cooldown_total = now


## The unit's current time between attacks, after status effects.
func get_attack_cooldown() -> float:
	var cooldown := Stats.attack_cooldown(get_stat(Stats.Stat.CELERITY))
	for status in _with(&"modify_attack_cooldown"):
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
	if health_bar != null:
		health_bar.add_child(attack_bar)   # on the plate, under the Charge bar (see _layout_plate)
	else:
		add_child(attack_bar)


## Extra timer bars stacked under the attack bar, one per timed weapon (COLUMN): see
## add_timer_bar.
var _timer_bars: Array[ProgressBar] = []


## Adds a thin bar in `color` to the bottom of the plate, for a timer of its own (COLUMN's
## weapons fill theirs as they wind up). Returns it, to set its value (0 to 1); null in
## lean sim mode, where nothing is drawn.
func add_timer_bar(color: Color) -> ProgressBar:
	if SimMode.active or health_bar == null:
		return null
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	health_bar.add_child(bar)
	_timer_bars.append(bar)
	_layout_plate()
	return bar


func remove_timer_bar(bar: ProgressBar) -> void:
	if bar == null:
		return
	_timer_bars.erase(bar)
	if is_instance_valid(bar):
		bar.queue_free()
	_layout_plate()


## Hides the attack bar, for units that never make normal attacks (COLUMN).
func hide_attack_bar() -> void:
	if attack_bar != null:
		attack_bar.visible = false
		_layout_plate()


## Hides the Charge bar, for units with no Gambit that never gain Charge (COLUMN).
func hide_charge_bar() -> void:
	if charge_bar != null:
		charge_bar.visible = false
		_layout_plate()


func _update_attack_bar() -> void:
	if SimMode.active:
		return   # lean sim mode: nothing is watching
	if attack_bar == null or health_bar == null:
		return
	var value := 1.0
	if _attack_cooldown_total > 0.0:
		value = 1.0 - _attack_timer / _attack_cooldown_total
	for status in _with(&"modify_attack_bar"):
		value = status.modify_attack_bar(self, value)
	attack_bar.value = value

## Splits the attack bar into `count` equal parts with thin dividers (SHRED's three
## attacks). 1 = a plain bar.
func set_attack_bar_segments(count: int) -> void:
	if attack_bar == null:
		return
	for child in attack_bar.get_children():
		if child.has_meta(&"segment_divider"):
			child.queue_free()
	for i in range(1, count):
		var divider := ColorRect.new()
		divider.set_meta(&"segment_divider", true)
		divider.color = Color(0.0, 0.0, 0.0, 0.85)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var at := float(i) / count
		divider.anchor_left = at
		divider.anchor_right = at
		divider.anchor_top = 0.0
		divider.anchor_bottom = 1.0
		divider.offset_left = -0.5
		divider.offset_right = 0.5
		attack_bar.add_child(divider)

## Keeps the unit from moving, attacking, or using a Gambit for `duration` seconds.
## For Gambits that control the unit themselves (dashes, channels). Also blocks charge gain.
func lock_for(duration: float) -> void:
	_locked_time = maxf(_locked_time, duration)

const STUN_TINT := Color(0.55, 0.55, 0.55)   # sprite darkens while stunned

## How long crowd control lasts on this unit, as a multiple (1 = normal). Stuns use it
## themselves; other crowd control (taunts, sleep, Clamp) applies it when it lands.
func crowd_control_multiplier() -> float:
	var multiplier := _immovability_factor()
	for status in statuses:
		multiplier = status.modify_crowd_control(self, multiplier)
	return maxf(multiplier, 0.0)

## How effective debuffs on this unit are, as a multiple (1 = normal). Timed debuffs
## shorten by it when they land; debuffs that last all combat weaken by it.
func debuff_multiplier() -> float:
	var multiplier := _immovability_factor()
	for status in statuses:
		multiplier = status.modify_debuff_strength(self, multiplier)
	return maxf(multiplier, 0.0)

## How much of a timed CC or debuff's duration lands: Immovability takes its percent off
## (40 Immovability = 40% shorter; 100 or more = none).
func _immovability_factor() -> float:
	return clampf(1.0 - get_stat(Stats.Stat.IMMOVABILITY) / 100.0, 0.0, 1.0)


## How strong a debuff without a duration is (Sapped stats, ward shred, auras, Mono-Virus):
## full, unless Immovability is 100 or more, which blocks it.
func debuff_strength() -> float:
	return 0.0 if get_stat(Stats.Stat.IMMOVABILITY) >= 100.0 else 1.0


## True while the unit is immune to crowd control: 100 or more Immovability (or a status
## that says so). Every CC effect checks this; pulls and knockbacks are only stopped by it.
func is_cc_immune() -> bool:
	if get_stat(Stats.Stat.IMMOVABILITY) >= 100.0:
		return true
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
	if projectile.team == team:
		return false   # an ally's shot (a Prancelot note) is never sent back
	for status in statuses.duplicate():
		if status.try_reflect(self, projectile):
			return true
	# It will hit: statuses that soften projectiles get their say (never on Pure Damage).
	if projectile.damage_type != Stats.DamageType.PURE:
		for status in _with(&"modify_incoming_projectile_damage"):
			projectile.damage = status.modify_incoming_projectile_damage(self, projectile.damage)
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
## `source` (the stunner, for its CONTROL wrack) is untyped on purpose: Gambits that wait
## (a hook's pull, a charge) may pass a caster who died meanwhile, and that's just ignored.
func stun(duration: float, source = null) -> void:
	if not alive or duration <= 0.0:
		return
	if is_instance_valid(source):
		duration *= source.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, self)
	if is_cc_immune():
		show_float_text("Immune", DODGE_COLOR)
		return
	duration *= crowd_control_multiplier()
	lock_for(duration)
	_stunned_time = maxf(_stunned_time, duration)
	if sprite != null:
		sprite.modulate = STUN_TINT
		sprite.create_tween().tween_property(sprite, "modulate", Color.WHITE, duration)
	_show_stun_swirl()
	crowd_controlled.emit(self)

var _stun_swirl: StunSwirl

## The swirling yellow stars over a stunned unit's head. Made the first time it's stunned
## (on screen only), then shown and hidden with the stun.
func _show_stun_swirl() -> void:
	if not KeepsakeVfx.enabled() or health_bar == null:
		return
	if _stun_swirl == null:
		_stun_swirl = StunSwirl.new()
		_stun_swirl.unit = self
		health_bar.add_child(_stun_swirl)
	_stun_swirl.visible = true


## Little yellow stars circling on a tilted ring above the unit's plate (and above its
## Keepsake icons and Von Carrow's shot tracker, so they never overlap).
class StunSwirl extends Control:
	const COLOR := Color(1.0, 0.88, 0.2)
	const OUTLINE := Color(0.05, 0.05, 0.07, 0.85)
	const RADIUS := Vector2(10.0, 3.5)
	const STARS := 3
	const SPIN := 7.0   # radians per second
	var unit: BattleUnit
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 25   # over damage numbers (20), which float up through the same spot

	func _process(delta: float) -> void:
		if visible:
			_time += delta
			queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(unit):
			return
		var plate := unit._plate
		var center_x: float = (plate.position.x + PLATE_WIDTH / 2.0) if is_instance_valid(plate) else unit.health_bar.size.x / 2.0
		var y := -PLATE_PAD - RADIUS.y - 4.0
		if unit._keepsake_icons != null and is_instance_valid(unit._keepsake_icons):
			y -= KEEPSAKE_ICON_SIZE + 1.0
		for status in unit.statuses:
			if status is PistolStatus:
				y -= 8.0   # clear of Von Carrow's shot tracker
		var center := Vector2(center_x, y)
		# A faint ring, then the stars on it (the ones at the back smaller and dimmer).
		var ring := PackedVector2Array()
		for i in 17:
			var a := TAU * i / 16.0
			ring.append(center + Vector2(cos(a) * RADIUS.x, sin(a) * RADIUS.y))
		draw_polyline(ring, Color(COLOR, 0.35), 1.0, true)
		for i in STARS:
			var a := _time * SPIN + TAU * i / STARS
			var front := (sin(a) + 1.0) / 2.0   # 1 at the front of the ring, 0 at the back
			var at := center + Vector2(cos(a) * RADIUS.x, sin(a) * RADIUS.y)
			_star(at, lerpf(2.0, 3.2, front), Color(COLOR, lerpf(0.55, 1.0, front)), a * 1.5)

	func _star(at: Vector2, size: float, color: Color, turn: float) -> void:
		var points := PackedVector2Array()
		for i in 8:
			var r := size if i % 2 == 0 else size * 0.45
			points.append(at + Vector2.from_angle(turn + TAU * i / 8.0) * r)
		var outline := PackedVector2Array()
		for i in 8:
			var r := (size if i % 2 == 0 else size * 0.45) + 0.8
			outline.append(at + Vector2.from_angle(turn + TAU * i / 8.0) * r)
		draw_colored_polygon(outline, OUTLINE)
		draw_colored_polygon(points, color)

## Ends any stun or lock right away, for effects like waking up.
func clear_stun() -> void:
	_locked_time = 0.0
	_stunned_time = 0.0
	if _stun_swirl != null:
		_stun_swirl.visible = false

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

## `show_numbers` off: no damage number (Scour's beam shows one total per attack instead).
## Damage that ignores Wards is Pure Damage (Stats.DamageType.PURE), whatever type it was
## given; Pure Damage always ignores them. `pass_through`: damage another unit's Wards
## already reduced and is only being passed on (Lord's Reach's cleave): skips Wards but
## keeps its type.
func take_damage(amount: float, wrack_level: int = 0, damage_type: int = Stats.DamageType.MIGHT,
		ignore_ward: bool = false, attacker: BattleUnit = null, show_numbers: bool = true,
		pass_through: bool = false) -> float:
	if not alive or previewing:
		return 0.0   # previewing: the planner's preview, where nothing lands
	if damage_type == Stats.DamageType.PURE:
		ignore_ward = true
	elif ignore_ward and not pass_through:
		damage_type = Stats.DamageType.PURE
	last_damage_type = damage_type
	dodging_attacker = attacker   # so dodge can depend on who's attacking (FRAME A)
	# Pure Damage can't be dodged (it can't be avoided or reduced in any way; only shields
	# soak it). No dodge roll at all, so the random sequence is the same as before otherwise.
	var dodged := damage_type != Stats.DamageType.PURE and CombatRng.randf() < get_dodge_chance()
	dodging_attacker = null
	if dodged:
		# What the hit would have done after Wards (FRAME A2 shields part of it).
		dodged_damage = amount if ignore_ward else amount * Stats.ward_multiplier(get_stat(Stats.ward_stat_for(damage_type)))
		show_float_text("Dodge", DODGE_COLOR)
		for status in statuses.duplicate():
			status.on_dodge(self)
		dodged_damage = 0.0
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
		amount = damage_bonus(attacker, self, amount)
	incoming_attacker = attacker
	incoming_damage_type = damage_type
	incoming_is_hit = true
	incoming_wrack_level = wrack_level
	var dealt := _apply_damage(amount, Stats.damage_color(damage_type, wrack_level), wrack_level, show_numbers)
	incoming_attacker = null
	_note_direct_damage(self, dealt, show_numbers)
	if attacker != null and dealt > 0.0 and is_instance_valid(attacker):
		for status in attacker._with(&"on_damage_landed").duplicate():
			status.on_damage_landed(attacker, self, dealt)
	return dealt

## Damage that has already been through wards, such as damage released over time.
## Shields and other statuses still apply. Leave show_numbers off for small, frequent
## amounts so they don't spam damage numbers.
func take_warded_damage(amount: float, show_numbers: bool = false, damage_type: int = Stats.DamageType.MIGHT) -> float:
	if not alive:
		return 0.0
	incoming_attacker = null
	incoming_damage_type = damage_type
	last_damage_type = damage_type   # for the meter's colours
	incoming_is_hit = false
	incoming_wrack_level = 0
	_note_direct_damage(self, 0.0, false)
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
## While a hit's dodge chance is being worked out: who's attacking (null for no attacker).
## Read by Status.modify_dodge_chance.
var dodging_attacker: BattleUnit = null
## During Status.on_dodge: the damage the dodged hit would have dealt, after Wards.
var dodged_damage := 0.0

func _apply_damage(amount: float, number_color: Color, wrack_level: int, show_numbers: bool) -> float:
	if previewing:
		return 0.0   # the planner's preview: nothing lands
	incoming_color = number_color
	var dealt := minf(amount, health + get_shield())
	var shield_before := get_shield()
	# Health left once held damage lands, measured before any status holds this hit, so
	# a held hit still flashes.
	var effective_before := health - get_pending_damage()
	# Pure Damage can't be reduced in any way: statuses that reduce, cap or hold back damage
	# (Status.reduces_damage) are skipped. Shields still soak it, since it's still damage
	# being dealt, and statuses that only watch, pass on or add to damage still run.
	var pure := incoming_damage_type == Stats.DamageType.PURE
	for status in statuses.duplicate():
		if pure and status.reduces_damage(self):
			continue
		amount = status.modify_incoming_damage(self, amount)
	if show_numbers:
		var absorbed := shield_before - get_shield()
		if absorbed > 0.0:
			_spawn_damage_number(absorbed, SHIELD_COLOR)
		if amount > 0.0:
			_spawn_damage_number(minf(amount, health), number_color, wrack_level)
		if absorbed > 0.0 or amount > 0.0:
			KeepsakeVfx.hit_flash(self)   # a direct hit: a quick white flash (steady ticks don't strobe)
	if amount > 0.0:
		damage_taken += minf(amount, maxf(health, 0.0))
	health -= amount
	_update_health_bar()
	_update_pending_bar()
	if show_numbers:
		_flash_health_loss(effective_before, health - get_pending_damage())
	if health <= 0.0 and not _escapes_death():
		_die()
	return dealt

## A status may save the unit from a hit that would kill it (Status.prevents_death, e.g.
## SEG.FAULT A1); it leaves the unit alive with at least 1 health. True if one did.
func _escapes_death() -> bool:
	for status in _with(&"prevents_death").duplicate():
		if status.prevents_death(self):
			health = maxf(health, 1.0)
			_update_health_bar()
			return true
	return false

## Font size for a damage number: from DAMAGE_FONT_MIN for tiny hits up to DAMAGE_FONT_MAX
## at DAMAGE_FOR_MAX_FONT, growing fast for small hits and levelling off (square root), plus
## WRACK_FONT_BONUS per wrack level. Worked out in fractions, rounded once at the end.
func _damage_font_size(amount: float, wrack_level: int) -> int:
	var t := clampf(amount / DAMAGE_FOR_MAX_FONT, 0.0, 1.0)   # 0 = tiny hit, 1 = huge hit
	t = sqrt(t)   # grows quickly for small hits, then levels off
	var font_size := lerpf(DAMAGE_FONT_MIN, DAMAGE_FONT_MAX, t)
	font_size += WRACK_FONT_BONUS * wrack_level
	return roundi(font_size)

func _spawn_damage_number(amount: float, color: Color = Color.WHITE, wrack_level: int = 0) -> void:
	var label := show_float_text(str(roundi(amount)), color, _damage_font_size(amount, wrack_level))
	if label != null and wrack_level > 0:
		add_wrack_icon(label)


## Colour of the little triangle beside a damage number that wracked.
const WRACK_ICON_COLOR := Color(0.7, 0.3, 1.0)

## Puts a small purple triangle just left of `label`'s text, marking a wracked hit. The
## triangle is a child of the label, so it rises and fades with it. Call again after the
## text changes (running numbers) to move it; it reuses the one already there.
static func add_wrack_icon(label: Label) -> void:
	var icon := label.get_node_or_null("WrackIcon") as Polygon2D
	var font_size := label.get_theme_font_size("font_size")
	var text_width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var size := maxf(font_size * 0.55, 4.0)
	if icon == null:
		icon = Polygon2D.new()
		icon.name = "WrackIcon"
		icon.color = WRACK_ICON_COLOR
		label.add_child(icon)
	icon.polygon = PackedVector2Array([Vector2(0, -size), Vector2(size * 0.9, size * 0.6), Vector2(-size * 0.9, size * 0.6)])
	# The label's text is centred in its box and sits on its bottom edge.
	icon.position = Vector2(label.size.x / 2.0 - text_width / 2.0 - size - 2.0, label.size.y - font_size * 0.45)


## Running damage numbers on this unit, by effect key (see add_running_damage).
var _running: Dictionary = {}

## Adds damage to this unit's running number for `key` (one per effect: "virus", "bleed",
## a beam's id, ...), so damage that keeps coming shows as one number that counts up and
## fades once it stops. A new number starts if the old one has already faded.
func add_running_damage(key: String, amount: float, color: Color, wrack_level: int = 0, linger: float = RunningNumber.LINGER) -> void:
	if amount <= 0.0 or not is_inside_tree() or not KeepsakeVfx.enabled():
		return
	var number = _running.get(key)   # untyped: it may have faded out and been freed
	if not is_instance_valid(number) or not number.is_open():
		var used := {}   # slots taken by numbers still counting, so a new one stacks above them
		for other in _running.values():
			if is_instance_valid(other) and other.is_open():
				used[other.slot] = true
		var slot := 0
		while used.has(slot):
			slot += 1
		number = RunningNumber.new()
		number.unit = self
		number.slot = slot
		number.size = FLOAT_TEXT_BOX
		number.pivot_offset = FLOAT_TEXT_BOX / 2.0
		number.rotation = view_rotation
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.z_index = 20
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_constant_override("outline_size", 4)
		get_tree().current_scene.add_child(number)   # not the unit's child, so it outlives a killing blow
		for old in _running.keys():   # forget finished ones
			if not is_instance_valid(_running[old]) or not _running[old].is_open():
				_running.erase(old)
		_running[key] = number
	number.linger = maxf(number.linger, linger)   # pulsing effects keep it up between pulses
	number.add(amount, color, wrack_level)
	number._process(0.0)   # place it above the unit right away

## Floating text that rises and fades above the unit. Statuses can use this too. Returns the
## label (null if the unit is off the board).
func show_float_text(text: String, color: Color = Color.WHITE, font_size: int = FLOAT_TEXT_FONT) -> Label:
	if SimMode.active:
		return null   # lean sim mode: nothing is watching
	if not is_inside_tree():
		return null   # off the board (cleared between rounds): nowhere to show it
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
	return label

func heal(amount: float, source_id: int = 0, can_wrack: bool = true) -> void:
	if previewing:
		return
	if not alive or amount <= 0.0:
		return
	var overheal := _with(&"on_overheal")   # statuses that want healing past max health
	if health >= max_health and overheal.is_empty():
		return
	if can_wrack:
		var healer := instance_from_id(source_id if source_id != 0 else get_instance_id()) as BattleUnit
		if healer != null:
			amount *= healer.wrack_effect_multiplier(Stats.EffectKind.HEALING, false, self)
	for status in _with(&"modify_healing_received"):
		amount = status.modify_healing_received(self, amount)
	if amount <= 0.0:
		return
	var healed := minf(amount, maxf(max_health - health, 0.0))
	var healer_id := source_id if source_id != 0 else get_instance_id()
	if healed > 0.0:
		health += healed
		_update_health_bar()
		_flash_health_gain(health - healed, health)   # the stretch of bar this heal filled
		get_tree().call_group("damage_tracker", "record_healing", healer_id, healed)
		for status in _with(&"on_healed").duplicate():
			status.on_healed(self, healed)
	if amount > healed:
		for status in overheal.duplicate():
			status.on_overheal(self, amount - healed)
	if healed > 0.0 and not _ally_heal_listeners.is_empty() and not _sharing_heal:
		_tell_ally_heal_listeners(healed)


## Units with a status that hears allies being healed (Status.on_ally_healed), by instance
## id. Statuses add and remove their unit (see listen_for_ally_heals); ids of units that
## have since left are dropped as they're found.
static var _ally_heal_listeners: Array[int] = []
## True while healing passed on to a listener is landing, so it isn't passed on again (two
## such units next to each other would otherwise hand the same healing back and forth).
static var _sharing_heal := false


static func listen_for_ally_heals(unit: BattleUnit, on: bool) -> void:
	var id := unit.get_instance_id()
	if on and not _ally_heal_listeners.has(id):
		_ally_heal_listeners.append(id)
	elif not on:
		_ally_heal_listeners.erase(id)


func _tell_ally_heal_listeners(healed: float) -> void:
	_sharing_heal = true
	for id in _ally_heal_listeners.duplicate():
		var listener := instance_from_id(id) as BattleUnit
		if listener == null or not is_instance_valid(listener):
			_ally_heal_listeners.erase(id)
			continue
		if listener == self or not listener.alive or listener.team != team:
			continue
		for status in listener._with(&"on_ally_healed"):
			status.on_ally_healed(listener, self, healed)
	_sharing_heal = false

## Sets current health directly, clamped to max. For summons that come back hurt.
func set_health(amount: float) -> void:
	health = clampf(amount, 0.0, max_health)
	_update_health_bar()

## The unit's current regen per second, after status effects.
## Charge per second this unit regenerates in combat (0 without the Insight rework).
func get_charge_regen() -> float:
	var base := data.charge_regen if data != null else 0.0
	return Stats.charge_regen(base, get_stat(Stats.Stat.INSIGHT))


func get_health_regen() -> float:
	var regen := health_regen
	for status in _with(&"modify_health_regen"):
		regen = status.modify_health_regen(self, regen)
	for status in _with(&"modify_final_health_regen"):
		regen = status.modify_final_health_regen(self, regen)
	return maxf(regen, 0.0)

func add_status(status: Status) -> void:
	statuses.append(status)
	_hook_lists.clear()
	status.on_applied(self)
	for other in statuses.duplicate():
		if other != status:
			other.on_status_added(self, status)
	status_added.emit(self, status)
	if status.is_permanent_stat_gain():
		gain_permanent_stats(status.get_permanent_stat_gains(), status is PermanentStatStatus and status.copied)


## Announces that this unit just gained permanent stats ({Stats.Stat: amount}), so effects
## that react to "gaining permanent stats" (Lordred A, Von Carrow A) see it. Statuses that
## stack a gain up themselves call this each time it grows; adding a permanent-gain status
## calls it automatically. `copied` marks a gain copied from an ally (Lordred), which isn't
## copied again, so two Lordreds can't copy each other forever.
func gain_permanent_stats(gains: Dictionary, copied := false) -> void:
	for status in statuses.duplicate():
		status.on_permanent_stats_gained(self, gains)
	permanent_stats_gained.emit(self, gains, copied)


func remove_status(status: Status) -> void:
	if statuses.has(status):
		statuses.erase(status)
		_hook_lists.clear()
		status.on_removed(self)


## Moves `status` to the front of the list, so its hooks run before every other status's.
func move_status_to_front(status: Status) -> void:
	if statuses.has(status):
		statuses.erase(status)
		statuses.push_front(status)
		_hook_lists.clear()


## For each status hook (a method name), the statuses whose class actually overrides it,
## in list order: the unit's hot loops (stats, regen, Charge, ticks) run only those instead
## of calling the base no-op on every status. Rebuilt whenever the list changes, so only
## change `statuses` through add_status, remove_status and move_status_to_front.
var _hook_lists := {}


func _with(hook: StringName) -> Array:
	var list = _hook_lists.get(hook)
	if list == null:
		list = []
		for status in statuses:
			if Status.overrides(status, hook):
				list.append(status)
		_hook_lists[hook] = list
	return list

## Total shield from all statuses.
## Healing this unit is still due from delayed heals, summed over its statuses.
func get_pending_healing() -> float:
	var total := 0.0
	for status in _with(&"get_pending_healing"):
		total += status.get_pending_healing(self)
	return total

## Damage this unit has taken but not lost yet, summed over its statuses.
func get_pending_damage() -> float:
	var total := 0.0
	for status in _with(&"get_pending_damage"):
		total += status.get_pending_damage(self)
	return total


func get_shield() -> float:
	var total := 0.0
	for status in _with(&"get_shield"):
		total += status.get_shield(self)
	return total

## Gives this unit a shield, after anything that changes shields it receives. Credits the
## shielding to `source_id` (the giver's instance id). `locks_charge`: a shield the unit's own
## Gambit gives it, which blocks Charge until it breaks or runs out. A unit's own shields
## absorb damage before anyone else's. Returns the shield actually given.
func add_shield(amount: float, duration: float, source_id: int, locks_charge := false) -> float:
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
	var shield := ShieldStatus.new(amount, duration)
	shield.source_id = source_id
	shield.locks_charge = locks_charge
	add_status(shield)
	place_own_shield(shield)
	get_tree().call_group("damage_tracker", "record_shielding", source_id, amount)
	return amount


## If `status` is one of this unit's own shields, moves it ahead of every shield from
## someone else, so it soaks damage first (and a Charge-locking one breaks sooner).
func place_own_shield(status: Status) -> void:
	if not status.is_own_shield(self) or not statuses.has(status):
		return
	var at := statuses.find(status)
	for i in at:
		var other: Status = statuses[i]
		if Status.overrides(other, &"get_shield") and not other.is_own_shield(self):
			statuses.remove_at(at)
			statuses.insert(i, status)
			_hook_lists.clear()
			return

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
	if SimMode.active:
		return   # lean sim mode: nothing is watching
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
	for status in _with(&"blocks_gambit"):
		if status.blocks_gambit(self):
			return false
	return gambit.can_use(self)

## Runs the Action and marks any statuses it attached, so they block charge gain.
func _run_gambit() -> void:
	# The Gambit is played: its cast time is over and it starts now.
	gambit_played.emit(self)
	for status in statuses.duplicate():
		status.on_gambit_played(self)
	if not alive:
		return
	var before := statuses.duplicate()
	var timer_before := _attack_timer
	gambit.execute(self)
	# The next attack winds up from the start after a cast, sized after the Gambit has run
	# so a Celerity buff it gives already counts for that first attack. If the Gambit set
	# the timer itself (e.g. by attacking), a longer wait it chose is kept.
	if gambit_resets_attack and alive:
		var full := get_attack_cooldown()
		_attack_timer = full if _attack_timer == timer_before else maxf(_attack_timer, full)
		_attack_cooldown_total = full   # the real cooldown, so _rescale_attack_timer leaves a longer wait alone
		_update_attack_bar()
	for status in statuses:
		if not before.has(status):
			status.from_gambit = true
	for status in statuses.duplicate():
		status.on_gambit_finished(self)

func _begin_gambit() -> void:
	gambit_cast.emit(self)
	charge = 0.0
	_update_charge_bar()
	for status in statuses.duplicate():
		status.on_gambit(self)
	gambit.on_cast(self)
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
	if previewing:
		return
	if not alive or _casting or _locked_time > 0.0:
		return
	for status in statuses:
		if status.blocks_charge_gain(self):
			return
	amount *= Stats.charge_multiplier(get_stat(Stats.Stat.INSIGHT))
	for status in _with(&"modify_charge_gain"):
		amount = status.modify_charge_gain(self, amount)
	var before := charge
	charge = minf(charge + amount, max_charge)
	_update_charge_bar()
	if charge > before:
		for status in statuses.duplicate():
			status.on_charge_gained(self, charge - before)

## TESTING: no flat Charge for being hit, for now: being hit gives Charge only for the damage
## taken (charge_per_damage). Set to true to bring the flat charge_on_hit back.
const FLAT_HIT_CHARGE := false

func gain_charge_from_attack(dealt: float, victim: BattleUnit = null) -> void:
	if dealt <= 0.0:
		return
	var amount := charge_on_attack
	for status in _with(&"modify_own_attack_charge"):
		amount = status.modify_own_attack_charge(self, amount)
	if victim != null:
		for status in victim.statuses:
			amount = status.modify_attacker_charge(victim, self, amount)
	gain_charge(amount)

## Charge for being hit by an attack: a share of the damage taken (plus a flat amount when
## FLAT_HIT_CHARGE is on).
func gain_charge_from_hit(taken: float) -> void:
	gain_charge((charge_on_hit if FLAT_HIT_CHARGE else 0.0) + taken * charge_per_damage)

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
	if _moving and not _step_switched:
		grid.vacate(_dest_cell, self)
	for status in statuses.duplicate():
		status.on_death(self)
	died.emit(self)
	ArmySpawner.bank_fallen(self)   # after died: a Glory earned from its own death still counts
	queue_free()
