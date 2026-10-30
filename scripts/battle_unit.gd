@tool

class_name BattleUnit
extends Node2D
## Grid-based auto battler unit. Scene structure: a Node2D root with this script,
## a ProgressBar named "HealthBar", plus whatever visuals you like.

signal died(unit: BattleUnit)

# Health bar fill color per team.
const TEAM_COLORS := {
	1: Color(0.25, 0.5, 1.0),   # blue
	2: Color(0.9, 0.25, 0.25),  # red
}

const HEALTH_TICK_INTERVAL := 200.0   # one line per this much max health
const HEALTH_TICK_WIDTH := 1.0        # line width in pixels
const SWING_TIME := 0.12          # seconds for the sword to sweep
const SWING_ARC := 0.9            # radians either side of the aim direction
const ATTACK_BAR_COLOR := Color(1.0, 0.85, 0.3)   # gold
var attack_bar: ProgressBar
var _attack_cooldown_total: float = 1.0
var _locked_time: float = 0.0

const BLOCKED_TARGET_TIMEOUT := 1.0   # seconds unable to reach a target before giving up on it
var _blocked_time: float = 0.0

const FLOAT_RISE := 40.0    # pixels the number drifts upward
const FLOAT_TIME := 0.8     # seconds before it fades out
const DAMAGE_FONT_MIN := 8          # font size for the smallest hits
const DAMAGE_FONT_MAX := 26          # font size for hits at or above DAMAGE_FOR_MAX_FONT
const DAMAGE_FOR_MAX_FONT := 400.0   # damage that reaches the biggest size
const WRACK_FONT_BONUS := 2          # wracks are this much bigger again
const DODGE_COLOR := Color(0.464, 0.464, 0.464, 1.0)
const CHARGE_COLOR := Color(0.6, 0.4, 1.0)   # purple, so it reads differently from the team-colored health bar
const CASTING_COLOR := Color(1.0, 0.45, 0.75)   # pink, while the bar drains
var _charge_fill: StyleBoxFlat

const SHIELD_COLOR := Color(0.565, 0.565, 0.565, 0.9)   # light gray
var shield_bar: ColorRect

const BADGE_SIZE := 6.0   # pixels, square
const BADGE_GAP := 2.0    # between badges, and between the badges and the health bar
## Badge color for the first and second choice at level 1. Shared by every unit.
const PATH_COLORS: Array[Color] = [Color(0.94, 0.55, 0.16), Color(0.18, 0.72, 0.69)]   # orange, teal
## How far a level-2 badge is shaded from its path color: lighter for the first
## follow-up, darker for the second.
const FOLLOW_UP_SHADE := 0.4

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


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_editor_preview()
		return
	
	add_to_group("units")

	grid = get_tree().get_first_node_in_group("battle_grid") as BattleGrid
	if grid == null:
		push_error("BattleUnit needs a BattleGrid in the scene.")
		return

	_apply_data()
	health = max_health
	_setup_health_bar()
	
	_setup_upgrade_badges()
	
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



## Copies stats from the UnitData resource, if one is assigned.
func _apply_data() -> void:
	if data == null:
		return
	var chosen := get_chosen_upgrades()
	var level := chosen.size()
	max_health = data.max_health * Stats.upgrade_health_multiplier(level)
	move_speed = 120
	attack_range = data.attack_range_cells
	health_regen = data.health_regen
	passives = data.passives.duplicate()   # a copy, so we never add to the shared resource
	gambit = data.gambit
	var bonuses := {}   # property name -> total amount to add
	for upgrade in chosen:
		passives.append_array(upgrade.passives)
		if upgrade.gambit != null:
			gambit = upgrade.gambit
			bonuses.clear()   # earlier bonuses were for the old Gambit
		for property in upgrade.gambit_bonuses:
			bonuses[property] = bonuses.get(property, 0.0) + upgrade.gambit_bonuses[property]
	if gambit != null and not bonuses.is_empty():
		gambit = _gambit_with_bonuses(gambit, bonuses)
	max_charge = data.max_charge
	starting_charge = data.starting_charge
	charge_on_attack = data.charge_on_attack
	charge_on_hit = data.charge_on_hit
	charge_per_damage = data.charge_per_damage
	for stat in Stats.Stat.values():
		base_stats[stat] = data.get_base_stat(stat) * Stats.upgrade_multiplier(stat, level)
	attack_damage_type = data.attack_damage_type
	if data.sprite != null and sprite != null:
		sprite.texture = data.sprite

## A copy of `base` with each bonus added to the matching property.
func _gambit_with_bonuses(base: Gambit, bonuses: Dictionary) -> Gambit:
	var copy := base.duplicate() as Gambit   # this unit's own copy; never change the shared file
	for property in bonuses:
		if not property in copy:
			push_warning("%s: upgrade bonus for unknown Gambit property '%s'." % [name, property])
			continue
		var current = copy.get(property)
		copy.set(property, current + type_convert(bonuses[property], typeof(current)))
	return copy

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
	fill.bg_color = TEAM_COLORS.get(team, Color.GRAY)
	health_bar.add_theme_stylebox_override("fill", fill)

	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	_update_health_bar()
	_setup_health_ticks()
	_update_health_ticks()
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

func _setup_shield_bar() -> void:
	shield_bar = ColorRect.new()
	shield_bar.color = SHIELD_COLOR
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
	shield_bar.position = Vector2(start_frac * width, 0.0)
	shield_bar.size = Vector2((end_frac - start_frac) * width, health_bar.size.y)
	shield_bar.visible = true

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

## Moves the unit onto `new_cell`, keeping position, `cell`, and grid occupancy in sync.
func place_at(new_cell: Vector2i) -> void:
	grid.vacate(cell, self)   # no-op if we weren't holding that cell
	cell = new_cell
	global_position = grid.cell_to_world(new_cell)
	grid.occupy(new_cell, self)


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

func start_combat() -> void:
	# Safety net: the stored cell must match where the unit is actually standing.
	clear_statuses()
	for passive in passives:
		passive.on_battle_start(self)
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


func stop_combat() -> void:
	_casting = false
	_update_charge_bar()
	active = false   # a step already in progress still finishes, so units stay on-grid
	_locked_time = 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not alive:
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	for status in statuses.duplicate():
		status.tick(self, delta)
	_update_shield_bar()
	_update_attack_bar()
	if active:
		heal(get_health_regen() * delta)

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
		_engaged = false
		target = _find_nearest_enemy()
		_blocked_time = 0.0
	if _ready_to_gambit():
		_begin_gambit()
		return
	if target == null:
		return

	if grid.get_distance(cell, target.cell) <= attack_range:
		_engaged = true
		if _attack_timer <= 0.0:
			_attack(target)
	else:
		if _engaged:
			# The target was in range and has since left it: pick a fresh target,
			# the same as if it had died.
			_engaged = false
			target = _find_nearest_enemy()
			_blocked_time = 0.0
			if target == null:
				return
		_start_step()

var _engaged: bool = false   # true once the current target has been in range

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
			target = _find_nearest_enemy(blocked)   # pick someone else
			_engaged = false
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


func _is_valid_target(u) -> bool:
	return is_instance_valid(u) and u.alive and u.team != team

var base_stats: Dictionary = {
	Stats.Stat.MIGHT: 100.0,
	Stats.Stat.INSIGHT: 100.0,
	Stats.Stat.CELERITY: 100.0,
	Stats.Stat.MIGHT_WARD: 20.0,
	Stats.Stat.INSIGHT_WARD: 20.0,
	Stats.Stat.CELERITY_WARD: 20.0,
	Stats.Stat.WRACK_CHANCE: 0.25,
	Stats.Stat.WRACK_DAMAGE: 0.3,
}
var attack_damage_type: int = Stats.DamageType.MIGHT

## A stat's current value: the unit's base, then every status's adjustments.
func get_stat(stat: Stats.Stat) -> float:
	var value: float = base_stats.get(stat, 0.0)
	for status in statuses:
		value = status.modify_stat(self, stat, value)
	return maxf(value, 0.0)

## Aura spent on this unit: its purchase price plus any upgrades.
func get_aura_value() -> int:
	if data == null:
		return 0
	return Economy.unit_aura_value(data.tier, get_upgrade_level())


## Reserve spent on this unit (items). Nothing costs Reserve yet.
func get_reserve_value() -> int:
	return 0

func _attack(enemy: BattleUnit) -> void:
	_attack_timer = get_attack_cooldown()
	_attack_cooldown_total = _attack_timer
	var chance := get_stat(Stats.Stat.WRACK_CHANCE)
	for status in statuses:
		chance = status.modify_wrack_chance(self, enemy, chance)
	var is_wrack := randf() < chance
	var base_damage := Stats.attack_damage(get_stat(Stats.Stat.MIGHT))
	var shot_color: Color = TEAM_COLORS.get(team, Color.WHITE)
	var hit_effects: Array[HitEffect] = []
	for status in statuses.duplicate():
		base_damage = status.modify_outgoing_damage(self, base_damage)
		shot_color = status.modify_projectile_color(self, shot_color)
		var effect : HitEffect = status.get_hit_effect(self)
		if effect != null:
			hit_effects.append(effect)
		status.on_attack(self)
	var hit_damage := base_damage * (1.0 + get_stat(Stats.Stat.WRACK_DAMAGE)) if is_wrack else base_damage
	if attack_range > 1:
		_fire_projectile(enemy, hit_damage, is_wrack, shot_color, hit_effects)
		return
	_play_melee_swing(enemy.global_position)
	var dealt := enemy.take_damage(hit_damage, is_wrack, get_attack_damage_type())
	get_tree().call_group("damage_tracker", "record_damage", get_instance_id(), dealt)
	gain_charge_from_attack(dealt)
	enemy.gain_charge_from_hit(dealt)
	notify_attack_hit(enemy, dealt)
	run_hit_effects(hit_effects, enemy, dealt, is_wrack)

func notify_attack_hit(enemy: BattleUnit, dealt: float) -> void:
	for status in statuses.duplicate():
		status.on_attack_hit(self, enemy, dealt)
	if not enemy.alive:
		for status in statuses.duplicate():
			status.on_kill(self, enemy)

## Runs the effects an attack collected when it was made. A dodged hit (nothing dealt)
## runs none, the same rule as charge.
static func run_hit_effects(effects: Array[HitEffect], hit_target: BattleUnit, dealt: float, is_wrack: bool) -> void:
	if dealt <= 0.0:
		return
	for effect in effects:
		effect.apply(hit_target, dealt, is_wrack)

func _fire_projectile(enemy: BattleUnit, hit_damage: float, is_wrack: bool, color: Color, hit_effects: Array[HitEffect]) -> void:
	var projectile := Projectile.new()
	projectile.setup(self, enemy, hit_damage, color, is_wrack, get_attack_damage_type(), hit_effects)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position


func _play_melee_swing(target_pos: Vector2) -> void:
	var sword := Line2D.new()
	sword.points = PackedVector2Array([Vector2(12, 0), Vector2(36, 0)])   # a bar pointing along +x
	sword.width = 5.0
	sword.default_color = Color.WHITE
	sword.z_index = 10
	add_child(sword)

	var aim := (target_pos - global_position).angle()
	sword.rotation = aim - SWING_ARC
	var tween := sword.create_tween()
	tween.tween_property(sword, "rotation", aim + SWING_ARC, SWING_TIME)
	tween.tween_callback(sword.queue_free)

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

## Stops the unit from moving, attacking, or using its Gambit for `duration` seconds.
## A step already in progress still finishes, so the unit stays on the grid.
func stun(duration: float) -> void:
	if not alive or duration <= 0.0:
		return
	lock_for(duration)
	if sprite != null:
		sprite.modulate = STUN_TINT
		sprite.create_tween().tween_property(sprite, "modulate", Color.WHITE, duration)

## Makes the unit attack `enemy` right now, ignoring range and attack timing. It's a real
## attack: it can wrack, triggers on-attack effects, and resets the attack timer.
func attack_now(enemy: BattleUnit) -> void:
	if alive and is_instance_valid(enemy) and enemy.alive:
		_attack(enemy)

func take_damage(amount: float, is_wrack: bool = false, damage_type: int = Stats.DamageType.MIGHT) -> float:
	if not alive:
		return 0.0
	if randf() < get_dodge_chance():
		show_float_text("Dodge", DODGE_COLOR)
		return 0.0   # nothing dealt: no meter credit, no lifesteal, no charge from damage
	# Wards come first. Shields and other effects apply to what's left.
	amount *= Stats.ward_multiplier(get_stat(Stats.ward_stat_for(damage_type)))
	return _apply_damage(amount, Stats.damage_color(damage_type, is_wrack), is_wrack, true)

## Damage that has already been through wards, such as damage released over time.
## Shields and other statuses still apply. Leave show_numbers off for small, frequent
## amounts so they don't spam damage numbers.
func take_warded_damage(amount: float, show_numbers: bool = false, damage_type: int = Stats.DamageType.MIGHT) -> float:
	if not alive:
		return 0.0
	return _apply_damage(amount, Stats.damage_color(damage_type), false, show_numbers)

## The number color of the hit currently being processed, for statuses that show their
## own numbers (like Bescard's held damage). Only meaningful during modify_incoming_damage.
var incoming_color: Color = Color.WHITE

func _apply_damage(amount: float, number_color: Color, is_wrack: bool, show_numbers: bool) -> float:
	incoming_color = number_color
	var dealt := minf(amount, health + get_shield())
	var shield_before := get_shield()
	for status in statuses.duplicate():
		amount = status.modify_incoming_damage(self, amount)
	if show_numbers:
		var absorbed := shield_before - get_shield()
		if absorbed > 0.0:
			_spawn_damage_number(absorbed, SHIELD_COLOR)
		if amount > 0.0:
			_spawn_damage_number(minf(amount, health), number_color, is_wrack)
	health -= amount
	_update_health_bar()
	if health <= 0.0:
		_die()
	return dealt

## Font size for a damage number: bigger for bigger hits, plus a bonus for wracks.
func _damage_font_size(amount: float, is_wrack: bool) -> int:
	var t := clampf(amount / DAMAGE_FOR_MAX_FONT, 0.0, 1.0)   # 0 = tiny hit, 1 = huge hit
	t = sqrt(t)   # grows quickly for small hits, then levels off
	var font_size := lerpf(DAMAGE_FONT_MIN, DAMAGE_FONT_MAX, t)
	if is_wrack:
		font_size += WRACK_FONT_BONUS
	return roundi(font_size)

func _spawn_damage_number(amount: float, color: Color = Color.WHITE, is_wrack: bool = false) -> void:
	show_float_text(str(roundi(amount)), color, _damage_font_size(amount, is_wrack))

## Floating text that rises and fades above the unit. Statuses can use this too.
func show_float_text(text: String, color: Color = Color.WHITE, font_size: int = DAMAGE_FONT_MIN) -> void:
	var label := Label.new()
	label.text = text
	label.size = Vector2(60, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)

	get_tree().current_scene.add_child(label)   # not a child of the unit, so it survives a killing blow
	label.global_position = global_position + Vector2(-30 + randf_range(-12.0, 12.0), -50)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - FLOAT_RISE, FLOAT_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TIME)
	tween.chain().tween_callback(label.queue_free)

## Restores health, capped at max. Credits the healing to `source_id` (a unit's
## instance id), or to this unit if none is given. Only health actually restored counts.
func heal(amount: float, source_id: int = 0) -> void:
	if not alive or amount <= 0.0 or health >= max_health:
		return
	var healed := minf(amount, max_health - health)
	health += healed
	_update_health_bar()
	var healer_id := source_id if source_id != 0 else get_instance_id()
	get_tree().call_group("damage_tracker", "record_healing", healer_id, healed)

## The unit's current regen per second, after status effects.
func get_health_regen() -> float:
	var regen := health_regen
	for status in statuses:
		regen = status.modify_health_regen(self, regen)
	return maxf(regen, 0.0)

func add_status(status: Status) -> void:
	statuses.append(status)
	status.on_applied(self)


func remove_status(status: Status) -> void:
	if statuses.has(status):
		statuses.erase(status)
		status.on_removed(self)

## Total shield from all statuses.
func get_shield() -> float:
	var total := 0.0
	for status in statuses:
		total += status.get_shield(self)
	return total


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
	return gambit != null and charge >= max_charge and gambit.can_use(self)

## Runs the Action and marks any statuses it attached, so they block charge gain.
func _run_gambit() -> void:
	var before := statuses.duplicate()
	gambit.execute(self)
	for status in statuses:
		if not before.has(status):
			status.from_gambit = true

func _begin_gambit() -> void:
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
	charge = minf(charge + amount, max_charge)
	_update_charge_bar()

## Charge for landing an attack. A hit that dealt nothing (dodged) gives none.
func gain_charge_from_attack(dealt: float) -> void:
	if dealt <= 0.0:
		return
	gain_charge(charge_on_attack)

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

func _die() -> void:
	alive = false
	remove_from_group("units")
	grid.vacate(cell, self)
	if _moving:
		grid.vacate(_dest_cell, self)
	died.emit(self)
	queue_free()
