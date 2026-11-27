class_name MatchGame
extends Node2D
## A match: you against the computer, or online against another player (see Net). Runs
## the rounds (Opening Shop, then Player Combats with an Encounter between each), the planning phase
## (shop, placing units, items, the ritual table), the combats, damage and income. The
## screen panels are MatchHud.
##
## Online, each player shops on their own computer and sends their finished army when
## they're ready (or when the planning time runs out). Both computers then play the same
## fight from the same armies and seed: the host's army as team 1 at the bottom, the
## joiner's as team 2 on the far side. The joiner watches it turned around so their own
## army is at the bottom. The host's result counts; each side also sends a fingerprint of
## how the fight ended, so any difference gets noticed.

## WAITING: you've readied (online, your army is sent) and are waiting for the opponent.
## Your army is locked in, but you can un-ready (press_ready again) to go back to planning
## until both players are ready: the round starts only once both are.
## ENCOUNTER: picking an Ascension between combats.
enum Phase { PLANNING, WAITING, COMBAT, RESULT, GAME_OVER, ENCOUNTER }

const PLAYER_TEAM := 1
const ENEMY_TEAM := 2
## Safety net: a combat still running after this many seconds ends as a draw.
## Overtime is meant to make sure this never happens.
const COMBAT_HARD_LIMIT := 180.0
## Where the board's centre sits on screen (HUD coordinates): centred across the screen,
## at BOARD_SCREEN_Y down. Set by _frame_camera from the visible width, which changes with
## the window's shape.
const BOARD_SCREEN_Y := 330.0
static var board_screen_center := Vector2(576, BOARD_SCREEN_Y)
## The board's top and bottom edges on screen (outer edges of its end rows of hexes).
const BOARD_TOP := 130.0
const BOARD_BOTTOM := 530.0
## Online only: seconds to plan before you're readied with the board as it stands.
const PLANNING_TIME := 60.0
## Off for now, so players have time to read everything: planning lasts until both are ready.
const PLANNING_TIMER_ON := false
const MENU_SCENE := "res://scenes/main_menu.tscn"

@onready var grid: BattleGrid = $BattleGrid
@onready var units_parent: Node2D = $BattleUnits
@onready var camera: Camera2D = $Camera2D
@onready var hud: MatchHud = $CanvasLayer/MatchHud
@onready var damage_tracker: DamageTracker = $CanvasLayer/DamageTracker
@onready var unit_info: UnitInfoPanel = $CanvasLayer/UnitInfoPanel
@onready var ai_planner: AiPlanner = $AiPlanner

var player := PlayerState.new()
var ai := PlayerState.new()
## Combat music (see CombatMusic): a track for music_faction() starts with each fight.
var combat_music: CombatMusic
## Set to play this track in every fight instead of picking one (null = pick).
var combat_track_override: CombatTrack = null
var round_number := 1
var combats_done := 0
var phase: Phase = Phase.PLANNING
var ai_ready := false
var log_lines: PackedStringArray = []

## What the mouse is holding: {} nothing, {"item": inventory index} or {"bench": ArmyUnit}.
var held: Dictionary = {}
## The unit whose items are listed in the panel.
var selected: ArmyUnit = null
## The ritual table's two slots: Shards taken out of the inventory, or null. From
## EMPOWER_ROUND a finished Keepsake can go there too, to be empowered by the Shard in the
## other slot (Keepsake Empowering).
var table: Array = [null, null]
## For each slot, the unit wearing the Keepsake there, or null. An equipped Keepsake never
## really leaves its unit: the table just points at it, and empowering it swaps the
## empowered copy in on the unit.
var table_links: Array = [null, null]

var _fog: MatchFog
var _manager: BattleManager
var _combat_time := 0.0
var _drag_unit: BattleUnit = null
var _drag_army: ArmyUnit = null

## Online: the other player is a person, and `ai` holds what we know of them (health and
## the army they last fielded). `ai_ready` then means "their army for this round arrived".
var online := false
## The team you fight as: 1 offline or as host, 2 when you joined.
var my_team := PLAYER_TEAM
var planning_left := 0.0
var _sent_army: Array = []          # online: the army you sent this round, as text
var _remote_armies: Dictionary = {} # online: round -> the opponent's army, as text
var _remote_ascensions: Dictionary = {} # online: round -> the opponent's Ascensions, as text
var _fight_over := false
var _my_fingerprint := ""
var _host_results: Dictionary = {}  # joiner: round -> the host's result
var _fingerprints: Dictionary = {}  # host: round -> the host's own fingerprint

## Watching mode: the computer plays both sides, match after match, with nothing to click.
## Set by the menu before it opens the match scene; the menu clears it again.
static var spectating := false
## Seconds to look at the board once both computers have planned, and at each result.
const SPECTATE_BOARD_PAUSE := 2.0
const SPECTATE_RESULT_PAUSE := 3.0
const SPECTATE_GAME_OVER_PAUSE := 6.0
## Every combat while watching is written here, to look back over.
const SPECTATE_LOG := "user://spectate_log.txt"
static var spectate_match_number := 0
var _blue_planner: AiPlanner
var _blue_ready := false

## Encounter: who has picked so far (the computer opponents pick with their planners).
var _player_picked := false
var _ai_picked := false
## The computer opponents' Ascension picks for the coming Encounter: "" not started,
## "running", or "done". They start as soon as the combat before it ends (see
## _start_early_picks), so they're usually done before you've chosen yours. What each one
## took waits in its summary until the Encounter, so the log doesn't give it away early.
var _ai_pick := ""
var _blue_pick := ""
var _ai_pick_summary := ""
var _blue_pick_summary := ""
## Encounter: the offer slot of a chosen-unit Ascension whose unit you're picking, or -1.
var _picking_slot := -1
## The unit chosen for that Ascension, waiting for Confirm (null: none yet).
var _pick_choice: ArmyUnit = null
var _encounter_heading := ""

## Factions picked in the menu: yours (Blue's when watching) and the computer's (Red's).
## Online, the opponent's comes from Net instead.
static var player_faction := MatchRules.DEFAULT_FACTION
static var opponent_faction := MatchRules.DEFAULT_FACTION
## What the menu's pickers chose, which may be MatchRules.RANDOM_FACTION. Each time the
## match scene starts (a new match, or the next watched match) these are rolled into
## player_faction and opponent_faction, so Random picks a fresh faction every match.
static var player_faction_choice := MatchRules.DEFAULT_FACTION
static var opponent_faction_choice := MatchRules.DEFAULT_FACTION


func _ready() -> void:
	add_to_group("match_game")   # descriptions find units on the board through it (MatchHud._board_unit)
	combat_music = CombatMusic.new()
	add_child(combat_music)
	# A background test copy that booted straight into a match (the main scene isn't the
	# menu): go to the tester instead of playing.
	if AiPlanner.is_eval_copy():
		get_tree().change_scene_to_file.call_deferred("res://scenes/ai_eval.tscn")
		return
	player.player_name = "You"
	ai.player_name = "Opponent"
	player.plays_sounds = not spectating   # spend sounds for the person playing here
	online = Net.is_online()
	if not online:   # online, your faction was settled (and sent) when you connected
		player_faction = MatchRules.resolve_faction(player_faction_choice)
		opponent_faction = MatchRules.resolve_faction(opponent_faction_choice)
	player.faction = player_faction
	ai.faction = Net.opponent_faction if online else opponent_faction
	var player_bottom := not online or Net.is_host()   # placeholder faction borders (see _start_combat)
	grid.team_factions = {PLAYER_TEAM: player.faction if player_bottom else ai.faction,
			ENEMY_TEAM: ai.faction if player_bottom else player.faction}
	if spectating:
		_setup_spectating()
	elif online:
		my_team = PLAYER_TEAM if Net.is_host() else ENEMY_TEAM
		Net.message.connect(_on_net_message)
		Net.opponent_left.connect(_on_opponent_left)
	else:
		ai.is_ai = true
		ai_planner.plan_ready.connect(_on_ai_plan_ready)
	if not online:
		# The computer's background copies, started now so they're ready by its first plan
		# and kept running all match (closed in _exit_tree).
		AiPool.start(ai_planner._copy_count())
	_fog = MatchFog.new()
	_fog.z_index = 30
	add_child(_fog)
	_frame_camera()
	get_viewport().size_changed.connect(_on_viewport_resized)
	hud.game = self
	add_child(EscapeMenu.new(return_to_menu))
	if DevPanel.available():   # testing tools, from the editor only (F1)
		hud.add_child(DevPanel.new(self))
	# In planning the meter shares the left strip with the unit info panel: it steps aside
	# while a unit is selected.
	# The damage meter is docked top-left all match; the unit info panel stacks under it.
	damage_tracker.dock_left(MatchHud.TOP_BAR_HEIGHT)
	damage_tracker.set_team_titles({my_team: player.player_name, 3 - my_team: ai.player_name}, my_team != PLAYER_TEAM)
	damage_tracker.expanded_changed.connect(func(_on): _layout_left.call_deferred())
	unit_info.unit_selected.connect(_on_unit_info_selected)
	_layout_left.call_deferred()
	add_log("Round 1: Opening Shop. Spend your starting Aura and Reserve.")
	_begin_planning()


## Centres the board where the panels leave room for it. `turned` looks at it rotated half
## a turn (the joiner watching the host's fight), with units and labels turned to match.
func _frame_camera(turned: bool = false) -> void:
	var box := Rect2(grid.cell_to_world(MatchRules.own_cells()[0]), Vector2.ZERO)
	for cell in MatchRules.own_cells():
		box = box.expand(grid.cell_to_world(cell)).expand(grid.cell_to_world(MatchRules.mirror_cell(cell)))
	var screen_center := get_viewport_rect().size / 2.0
	board_screen_center = Vector2(screen_center.x, BOARD_SCREEN_Y)
	var shift := (screen_center - board_screen_center) / camera.zoom
	camera.ignore_rotation = false
	camera.rotation = PI if turned else 0.0
	camera.position = box.get_center() + (-shift if turned else shift)
	BattleUnit.view_rotation = PI if turned else 0.0
	BattleUnit.swap_team_colors = my_team != PLAYER_TEAM and turned
	grid.queue_redraw()   # the board tint follows the colour swap


## The window changed shape: re-centre the board and everything placed around it.
func _on_viewport_resized() -> void:
	_frame_camera(BattleUnit.view_rotation != 0.0)
	hud.refresh()


func combat_number() -> int:
	return combats_done + 1


func is_opening() -> bool:
	return round_number == 1


func add_log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 6:
		log_lines.remove_at(0)


# ---------- Planning ----------

## The Round Announcement (MatchHud.announce_round): the last round it showed, the
## Empowered Keepsake limit then, and what your last combat paid.
var _announced_round := 0
var _announced_empower_limit := 0
var _round_income: Dictionary = {}


func _begin_planning() -> void:
	phase = Phase.PLANNING
	if is_instance_valid(_manager):   # the last combat's; the combat timer reads it
		_manager.queue_free()
	_manager = null
	held = {}
	selected = null
	_frame_camera()
	for p in [player, ai]:
		MatchRules.start_planning(p, combat_number())
	# The last fight's meter stays up so it can inform planning (hidden before the first).
	damage_tracker.set_planning(true)
	_show_planning_board()
	_announce_round()
	if online:
		ai_ready = _remote_armies.has(round_number)   # they may have finished already
		planning_left = PLANNING_TIME
		hud.refresh()
		return
	ai_ready = false
	hud.refresh()
	# The opponent plans against the army you last fielded, just as you see theirs.
	ai_planner.plan(ai, player.last_fielded, combat_number(), player.last_fielded_ascensions)
	if spectating:
		_blue_ready = false
		_blue_planner.plan(player, ai.last_fielded, combat_number(), ai.last_fielded_ascensions)


## The first planning of each round (as players count them): a banner with the round
## number and what's new: the Aura and Reserve you just got (your starting amounts in
## Round 1) and any new Empowered Keepsake slots.
func _announce_round() -> void:
	var shown := MatchRules.display_round(round_number)
	if shown == _announced_round or spectating:
		return
	var aura: int = player.aura if round_number == 1 else int(_round_income.get("aura", 0))
	var reserve: int = player.reserve if round_number == 1 else int(_round_income.get("reserve", 0))
	var limit := MatchRules.empowered_limit(round_number)
	hud.announce_round(shown, aura, reserve, limit - _announced_empower_limit, limit)
	_announced_round = shown
	_announced_empower_limit = limit


## Online: counts down the planning time, then readies you with the board as it stands.
## The left side: the damage meter at the top, the unit info panel under it. Opening the
## panel folds the meter to its title bar (and closing it unfolds it again, if it was
## folded for the panel). Unfolding the meter while the panel is open pushes the panel down
## and lets it use the log's corner too.
var _meter_folded_for_info := false

func _on_unit_info_selected(unit: BattleUnit) -> void:
	hud.refresh_selected()
	if unit != null and damage_tracker.expanded:
		_meter_folded_for_info = true
		damage_tracker.set_expanded(false)   # calls _layout_left
	elif unit == null and _meter_folded_for_info:
		_meter_folded_for_info = false
		damage_tracker.set_expanded(true)
	else:
		_layout_left.call_deferred()


func _layout_left() -> void:
	if damage_tracker.expanded and unit_info.visible:
		_meter_folded_for_info = false   # the player unfolded it on purpose
	unit_info.top_reserve = damage_tracker.bottom_edge() + 6.0
	unit_info.bottom_reserve = 8.0 if damage_tracker.expanded else MatchHud.INFO_BOTTOM_RESERVE
	unit_info.relayout()


func _process(delta: float) -> void:
	if not online or phase != Phase.PLANNING or not PLANNING_TIMER_ON:
		return
	var shown := ceili(planning_left)
	planning_left -= delta
	if planning_left <= 0.0:
		add_log("Time's up: your army is locked in as it stands.")
		press_ready()
	elif ceili(planning_left) != shown:
		hud.refresh_top()


func _on_ai_plan_ready(summary: String) -> void:
	if _ai_pick == "running":
		_ai_pick = "done"
		_ai_pick_summary = summary
		if phase == Phase.ENCOUNTER:
			_ai_picked = true
			_log_pick_summaries()
			_try_end_encounter()
		return
	ai_ready = true
	add_log(summary + ".")
	if spectating:
		_spectate_try_fight()
	hud.refresh()
	_try_proceed()   # you may have readied while it was still planning


## Your army on your half; the opponent's last fielded army under the fog on theirs.
func _show_planning_board() -> void:
	_clear_board()
	var units := ArmySpawner.spawn(player.units, PLAYER_TEAM, false, units_parent, player.ascensions)
	for unit in ArmySpawner.spawn(ai.last_fielded, ENEMY_TEAM, true, units_parent, ai.last_fielded_ascensions):
		unit.modulate.a = 0.6
		units.append(unit)
	# Everything that starts with combat shows while planning too: stats, shields, auras
	# (Lunck's, Battery's, Keepsakes'), other visuals. Once all are on the board.
	for unit in units:
		unit.preview_combat_start()
	# Units you can afford to upgrade right now: a cyan glow and arrow (while planning only).
	if phase == Phase.PLANNING and not spectating:
		for unit in units:
			if unit.team == PLAYER_TEAM:
				KeepsakeVfx.upgrade_ready(unit, MatchRules.upgrade_affordable(player, _army_of(unit)))
	_fog.show_fog(grid, ai.faction, ai.last_fielded_round)


func _clear_board() -> void:
	for child in units_parent.get_children():
		units_parent.remove_child(child)
		child.queue_free()
	grid.clear_occupants()


## Rebuilds the board and the panels after anything in the planning phase changes.
func changed() -> void:
	_check_table_links()
	if phase == Phase.PLANNING:
		_show_planning_board()
	hud.refresh()


func buy_unit(slot: int, choice: int = -1) -> void:
	if phase != Phase.PLANNING:
		return
	var data := player.unit_offers[slot]
	var bought := MatchRules.buy_unit_offer(player, slot, choice)
	var info := player.find_unit(data)
	if bought:
		add_log("Bought %s." % (info.label() if info != null else data.display_name))
	changed()


## Aura upgrade system: buys `unit`'s next upgrade from its upgrade menu (planning only).
func buy_upgrade(unit: ArmyUnit, choice: int) -> void:
	if phase != Phase.PLANNING:
		return
	var bought := MatchRules.buy_upgrade(player, unit, choice)
	if bought:
		add_log("Upgraded %s." % unit.label())
	changed()
	if bought and unit.placed:
		_play_upgrade_flourish(unit)


## The faction's upgrade animation around `unit`'s figure on the board (just rebuilt).
func _play_upgrade_flourish(unit: ArmyUnit) -> void:
	var index := player.units.find(unit)
	for node in units_parent.get_children():
		var shown := node as BattleUnit
		if shown != null and shown.team == PLAYER_TEAM and shown.get_meta("army_index", -1) == index:
			KeepsakeVfx.upgrade_flourish(shown, MatchRules.faction_of(unit.data))
			return


func buy_shard(slot: int) -> void:
	if phase == Phase.PLANNING and MatchRules.buy_shard_offer(player, slot):
		changed()


func buy_keepsake() -> void:
	if phase == Phase.PLANNING and MatchRules.buy_keepsake_offer(player):
		add_log("Bought %s." % player.inventory[-1].get_display_name())
		changed()


## Rerolls the units, the Shards and the Keepsake together.
func reroll() -> void:
	if phase == Phase.PLANNING and MatchRules.reroll(player, combat_number()):
		changed()


## Locks the shop so the next planning phase keeps it, or unlocks it again.
func toggle_shop_lock() -> void:
	if phase == Phase.PLANNING:
		player.shop_locked = not player.shop_locked
		hud.refresh()


func hold_item(index: int) -> void:
	held = {} if held.get("item", -1) == index else {"item": index}
	hud.refresh()


func sell_held() -> void:
	if held.has("item") and MatchRules.sell_item(player, held["item"]):
		held = {}
		changed()


## Clicking a bench unit: gives it the held item, or picks it up to place it.
func bench_clicked(unit: ArmyUnit) -> void:
	selected = unit
	if held.has("item"):
		MatchRules.equip(player, unit, held["item"])
		held = {}
		changed()
		return
	held = {} if held.get("bench") == unit else {"bench": unit}
	hud.refresh()


func unequip(unit: ArmyUnit, item_index: int) -> void:
	if MatchRules.unequip(player, unit, item_index):
		changed()


## Puts the held Shard (or, from EMPOWER_ROUND, Keepsake) on the ritual table, or takes
## an item off it.
func table_clicked(slot: int) -> void:
	if table[slot] != null:
		_clear_table_slot(slot)
	elif held.has("item") and table_accepts(player.inventory[held["item"]]):
		table[slot] = player.inventory[held["item"]]
		player.inventory.remove_at(held["item"])
		held = {}
	changed()


## True if `item` may go on the ritual table: any Shard, and from EMPOWER_ROUND a
## finished Keepsake that isn't empowered yet.
func table_accepts(item: Keepsake) -> bool:
	if item == null:
		return false
	if item.is_shard:
		return true
	return MatchRules.empowering_open(round_number) and not item.is_empowered()


## Takes the item off a table slot: back to the inventory, or (an equipped Keepsake) just
## no longer pointed at, as it never left its unit.
func _clear_table_slot(slot: int) -> void:
	if table[slot] != null and table_links[slot] == null:
		player.inventory.append(table[slot])
	table[slot] = null
	table_links[slot] = null


## Drops table links to Keepsakes their unit no longer has (the unit was sold).
func _check_table_links() -> void:
	for slot in table.size():
		var unit = table_links[slot]
		if unit != null and (not player.units.has(unit) or not unit.items.has(table[slot])):
			table[slot] = null
			table_links[slot] = null


func table_preview() -> Keepsake:
	var made := MatchRules.combine_result(table[0], table[1])
	if made != null:
		return made
	return _empower_preview()


## The empowered Keepsake the table would make, or null (not open yet, no Empowerment for
## that Shard, or its unit already carries as many empowered Keepsakes as it may).
func _empower_preview() -> Keepsake:
	var slot := _table_keepsake_slot()
	if slot == -1 or not MatchRules.can_empower(table[slot], table[1 - slot], table_links[slot], round_number, player):
		return null
	return MatchRules.empower_result(table[0], table[1])


## True if the table holds a Keepsake beside a Shard (empowering, not combining).
func is_empowering_on_table() -> bool:
	return _table_keepsake_slot() != -1


## The slot holding a finished Keepsake beside a Shard, or -1.
func _table_keepsake_slot() -> int:
	for slot in table.size():
		if table[slot] != null and not table[slot].is_shard \
				and table[1 - slot] != null and table[1 - slot].is_shard:
			return slot
	return -1


## Why the table can't empower what's on it, for its hint; "" if it can (or isn't trying).
func empower_problem() -> String:
	var slot := _table_keepsake_slot()
	if slot == -1:
		return ""
	var keepsake: Keepsake = table[slot]
	if not MatchRules.empowering_open(round_number):
		return "Keepsakes can be empowered from round %d." % MatchRules.display_round(MatchRules.EMPOWER_ROUND)
	if MatchRules.empower_result(table[0], table[1]) == null:
		return "A %s Shard can't empower %s." % [Shard.NAMES[table[1 - slot].first_shard], keepsake.get_display_name()]
	var limit := MatchRules.empowered_limit(round_number)
	var owned := MatchRules.empowered_owned(player)
	if owned >= limit:
		return "Your army already has %d of %d empowered Keepsakes. The limit grows after each Neutral Encounter." % [owned, limit]
	var wearer: ArmyUnit = table_links[slot]
	if wearer != null and wearer.empowered_count() >= wearer.empowered_cap():
		return "%s can't carry another empowered Keepsake." % wearer.label()
	return ""


func combine_table() -> void:
	var result := table_preview()
	if result == null:
		return
	Sfx.play(get_tree(), Sfx.RITUAL, 0.0, 0.03)
	if _table_keepsake_slot() != -1:
		_empower_table()
		changed()
		return
	player.inventory.append(result)
	table = [null, null]
	table_links = [null, null]
	add_log("The ritual made %s." % result.get_display_name())
	changed()


## Empowers the Keepsake on the table with the Shard beside it. The result takes the
## Keepsake's place: on its unit, or in the inventory. Returns it, or null.
func _empower_table() -> Keepsake:
	var slot := _table_keepsake_slot()
	if slot == -1 or _empower_preview() == null:
		return null
	var keepsake: Keepsake = table[slot]
	var shard: Keepsake = table[1 - slot]
	for s in table.size():   # loose items back to the inventory, where empower finds them
		_clear_table_slot(s)
	var result := MatchRules.empower(player, keepsake, shard, round_number)
	if result == null:
		return null
	add_log("The ritual empowered %s with a %s Shard." % [keepsake.get_display_name(), Shard.NAMES[shard.first_shard]])
	return result


# ---------- Dragging items ----------

## Where a dragged item comes from: {"from": "inventory", "index": i},
## {"from": "table", "slot": s}, {"from": "unit", "unit": ArmyUnit, "index": i}, or (bought
## or made as it's placed) {"from": "shop_shard", "slot": s}, {"from": "shop_keepsake"} and
## {"from": "table_result"}.
## Where it goes: {"to": "inventory"}, {"to": "table", "slot": s} or {"to": "unit", "unit": ArmyUnit}.

func item_at(source: Dictionary) -> Keepsake:
	match source.get("from"):
		"inventory":
			var i: int = source["index"]
			return player.inventory[i] if i >= 0 and i < player.inventory.size() else null
		"table":
			return table[source["slot"]]
		"unit":
			var unit: ArmyUnit = source["unit"]
			var i: int = source["index"]
			return unit.items[i] if player.units.has(unit) and i >= 0 and i < unit.items.size() else null
		"shop_shard":
			var s: int = source["slot"]
			return player.shard_offers[s] if s >= 0 and s < player.shard_offers.size() else null
		"shop_keepsake":
			return player.keepsake_offer
		"table_result":
			return table_preview()
	return null


## True for sources that are bought or made when they're placed (shop offers, the ritual's
## result): they can only go to the inventory or onto a unit.
func _is_new_item(source: Dictionary) -> bool:
	return source.get("from") in ["shop_shard", "shop_keepsake", "table_result"]


## True if the item at `source` may go to `dest`. Only Shards go on the table or come off a
## unit; keepsakes stay on the unit wearing them.
func can_move_item(source: Dictionary, dest: Dictionary) -> bool:
	if phase != Phase.PLANNING or spectating:
		return false
	var item := item_at(source)
	if item == null:
		return false
	if source["from"] == "unit" and not item.is_shard:
		# A Keepsake stays on its unit; it can only be pointed at from the ritual table, to
		# be empowered (from EMPOWER_ROUND).
		return dest.get("to") == "table" and table_accepts(item) and not table.has(item)
	if source["from"] == "table" and table_links[source["slot"]] != null and dest.get("to") == "unit":
		return false   # an equipped Keepsake on the table belongs to its unit already
	if _is_new_item(source):
		if source["from"] == "shop_shard" and player.reserve < MatchRules.SHARD_COST:
			return false
		if source["from"] == "shop_keepsake" and player.reserve < MatchRules.KEEPSAKE_COST:
			return false
		if dest.get("to") == "unit":
			var target: ArmyUnit = dest["unit"]
			# A copy it already has may still be dropped on it: it's refused (see move_item).
			return player.units.has(target) and (target.items.size() < target.keepsake_slots() \
					or not target.accepts(item))
		return dest.get("to") == "inventory"
	match dest.get("to"):
		"inventory":
			return source["from"] != "inventory"
		"table":
			return table_accepts(item) and not (source["from"] == "table" and source["slot"] == dest["slot"])
		"unit":
			var unit: ArmyUnit = dest["unit"]
			if not player.units.has(unit) or (source["from"] == "unit" and source["unit"] == unit):
				return false
			# A copy it already has may still be dropped on it: it's refused (see move_item).
			return unit.items.size() < unit.keepsake_slots() or not unit.accepts(item)
	return false


## Moves an item by dragging. A Shard dropped on a full table slot swaps places with the
## one there if it came from the other slot; otherwise the one there goes to the inventory.
func move_item(source: Dictionary, dest: Dictionary) -> void:
	if not can_move_item(source, dest):
		return
	# The universal Keepsake rule: a unit never carries two of the same completed Keepsake.
	# The copy goes to the inventory instead (bought or made first, if it's new) and the
	# unit refuses it with a red outline and a shake.
	if dest.get("to") == "unit" and not dest["unit"].accepts(item_at(source)):
		_refuse_item(source, dest["unit"])
		return
	if _is_new_item(source):
		_place_new_item(source, dest)
		return
	var item := item_at(source)
	var bumped: Keepsake = null
	var bumped_link = null
	var link = null   # the unit wearing the moved Keepsake, if it stays on it (see table_links)
	if dest["to"] == "table":
		bumped = table[dest["slot"]]
		bumped_link = table_links[dest["slot"]]
		table[dest["slot"]] = null
		table_links[dest["slot"]] = null
	match source["from"]:
		"inventory":
			player.inventory.remove_at(source["index"])
		"table":
			link = table_links[source["slot"]]
			table[source["slot"]] = null
			table_links[source["slot"]] = null
		"unit":
			if item.is_shard:
				source["unit"].items.remove_at(source["index"])
			else:
				link = source["unit"]   # an equipped Keepsake: the table only points at it
	if bumped != null:
		if source["from"] == "table":
			table[source["slot"]] = bumped
			table_links[source["slot"]] = bumped_link
		elif bumped_link == null:
			player.inventory.append(bumped)
	match dest["to"]:
		"inventory":
			if link == null:   # an equipped Keepsake taken off the table just stays on its unit
				player.inventory.append(item)
		"table":
			table[dest["slot"]] = item
			table_links[dest["slot"]] = link
		"unit":
			player.inventory.append(item)
			MatchRules.equip(player, dest["unit"], player.inventory.size() - 1)
			selected = dest["unit"]
	held = {}
	changed()


## A Keepsake `unit` already has a copy of, dropped on it: the item ends up in the
## inventory (bought or made, if it came from the shop or the ritual table; taken off the
## table if it was there; left where it is if it came from the inventory), and the unit
## refuses it.
func _refuse_item(source: Dictionary, unit: ArmyUnit) -> void:
	var item := item_at(source)
	if _is_new_item(source):
		_place_new_item(source, {"to": "inventory"})
	else:
		match source["from"]:
			"table":
				_clear_table_slot(source["slot"])
		held = {}
		changed()
	if Keepsake.allowed_with(item, unit.items):   # refused for the empowered limit instead
		add_log("%s can't carry another empowered Keepsake." % unit.label())
	else:
		add_log("%s already has %s." % [unit.label(), item.get_display_name()])
	_play_refusal(unit)


## The red outline and "no" shake on `unit`'s figure on the board (just rebuilt).
func _play_refusal(unit: ArmyUnit) -> void:
	var index := player.units.find(unit)
	for node in units_parent.get_children():
		var shown := node as BattleUnit
		if shown != null and shown.team == PLAYER_TEAM and shown.get_meta("army_index", -1) == index:
			KeepsakeVfx.refuse(shown)
			return
	hud.flash_refusal(unit)   # on the bench: its tile shakes instead


## Buys (a shop offer) or makes (the ritual's result) the item at `source`, and puts it in
## the inventory or on the unit at `dest`.
func _place_new_item(source: Dictionary, dest: Dictionary) -> void:
	var made := false
	match source["from"]:
		"shop_shard":
			made = MatchRules.buy_shard_offer(player, source["slot"])
		"shop_keepsake":
			made = MatchRules.buy_keepsake_offer(player)
			if made:
				add_log("Bought %s." % player.inventory[-1].get_display_name())
		"table_result":
			if _table_keepsake_slot() != -1:
				# Empowering: the result takes the Keepsake's place (on its unit, or in the
				# inventory, from where it may then go onto the unit it was dropped on).
				var empowered := _empower_table()
				if empowered != null and dest["to"] == "unit" and player.inventory.has(empowered):
					MatchRules.equip(player, dest["unit"], player.inventory.find(empowered))
					selected = dest["unit"]
				held = {}
				changed()
				return
			var result := table_preview()
			if result != null:
				player.inventory.append(result)
				table = [null, null]
				table_links = [null, null]
				add_log("The ritual made %s." % result.get_display_name())
				made = true
	if made and dest["to"] == "unit":
		MatchRules.equip(player, dest["unit"], player.inventory.size() - 1)
		selected = dest["unit"]
	held = {}
	changed()


## Left-clicking a Shard anywhere but the inventory: it goes to the inventory (a shop Shard
## is bought). True if it moved.
func shard_to_inventory(source: Dictionary) -> bool:
	var item := item_at(source)
	if item == null or not item.is_shard or source.get("from") == "inventory":
		return false
	if source["from"] == "shop_shard":
		buy_shard(source["slot"])
		return true
	if not can_move_item(source, {"to": "inventory"}):
		return false
	move_item(source, {"to": "inventory"})
	return true


## Right-clicking a Shard anywhere: it goes to the first free ritual table slot (a shop
## Shard is bought first; with the table full it stays in the inventory). True if it moved.
func shard_to_table(source: Dictionary) -> bool:
	var item := item_at(source)
	if item == null or not table_accepts(item) or phase != Phase.PLANNING or spectating:
		return false   # from EMPOWER_ROUND, Keepsakes go there too (to be empowered)
	if source["from"] == "table":
		return false   # already there
	if source["from"] == "shop_shard":
		if not MatchRules.buy_shard_offer(player, source["slot"]):
			return false
		source = {"from": "inventory", "index": player.inventory.size() - 1}
	for slot in table.size():
		if table[slot] == null and can_move_item(source, {"to": "table", "slot": slot}):
			move_item(source, {"to": "table", "slot": slot})
			return true
	changed()   # bought, but the table was full: it waits in the inventory
	return source["from"] == "inventory"


## A screen position (as the HUD sees it) on the board.
func screen_to_world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


## True if a bench unit dragged to this screen position would land on one of your cells.
func can_place_at_screen(screen: Vector2) -> bool:
	return phase == Phase.PLANNING and not spectating \
			and MatchRules.is_own_cell(grid.world_to_cell(screen_to_world(screen)))


## Places a unit dragged from the bench on the cell at this screen position. A unit
## already there goes to the bench.
func place_at_screen(unit: ArmyUnit, screen: Vector2) -> void:
	if not can_place_at_screen(screen) or not player.units.has(unit):
		return
	if MatchRules.place(player, unit, grid.world_to_cell(screen_to_world(screen))):
		held = {}
		selected = unit
		changed()


## Your unit standing at a screen position, or null.
func own_army_unit_at_screen(screen: Vector2) -> ArmyUnit:
	var unit := _own_unit_near(screen_to_world(screen))
	return _army_of(unit) if unit != null else null


func _return_table() -> void:
	for slot in 2:
		_clear_table_slot(slot)


# ---------- Moving units on the board ----------

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.ENCOUNTER and _picking_slot >= 0:
		_pick_input(event)
		return
	if phase != Phase.PLANNING or spectating:
		return
	var world := get_global_mouse_position()
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		var badge := _badge_source_at(world)
		if not badge.is_empty() and shard_to_table(badge):
			return
		held = {}
		hud.refresh()
		return
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press(world)
		elif not _pending_badge.is_empty():
			var badge := _pending_badge
			_pending_badge = {}
			shard_to_inventory(badge)   # a click, not a drag: off the unit
		elif _drag_unit != null:
			_release(world, button.position)
	elif event is InputEventMouseMotion:
		if not _pending_badge.is_empty() and world.distance_to(_pending_at) > BADGE_DRAG_START:
			var badge := _pending_badge
			_pending_badge = {}
			hud.start_item_drag(badge)
		elif _drag_unit != null:
			_drag_unit.global_position = world


## Picking a unit for a chosen-unit Ascension: left-click one of yours to choose it (the unit
## info panel shows it too), then Confirm in the banner; left-click empty ground to choose
## none; right-click to go back to the cards.
func _pick_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		cancel_unit_pick()
	elif button.button_index == MOUSE_BUTTON_LEFT:
		var unit := _own_unit_near(get_global_mouse_position())
		var army := _army_of(unit) if unit != null else null
		if army != null and player.ascension_offers[_picking_slot].can_pick(army):
			choose_pick_target(army)
		elif unit == null:
			choose_pick_target(null)


## Chooses `unit` (or none) as the one to get the Ascension being picked for. Confirm gives
## it (confirm_unit_pick).
func choose_pick_target(unit: ArmyUnit) -> void:
	if phase != Phase.ENCOUNTER or _picking_slot < 0:
		return
	_pick_choice = unit
	hud.set_unit_pick_choice(unit)
	if unit != null and not unit.placed:
		unit_info._select(null)   # a bench unit isn't on the board: its details show in the banner's popup


## The banner's Confirm: gives the Ascension to the chosen unit.
func confirm_unit_pick() -> void:
	if _pick_choice != null:
		pick_unit(_pick_choice)


func _press(world: Vector2) -> void:
	var cell := grid.world_to_cell(world)
	var unit := _own_unit_near(world)
	if held.has("item"):
		if unit != null:
			MatchRules.equip(player, _army_of(unit), held["item"])
			selected = _army_of(unit)
		held = {}
		changed()
		return
	if held.has("bench"):
		if MatchRules.place(player, held["bench"], cell):
			held = {}
		changed()
		return
	# A Shard's badge above a unit's health bar: click it off, or drag it somewhere.
	var badge := _badge_source_at(world)
	if not badge.is_empty():
		selected = badge["unit"]
		_pending_badge = badge
		_pending_at = world
		return
	if unit != null:
		_drag_unit = unit
		_drag_army = _army_of(unit)
		_drag_unit.z_index = 20
		selected = _drag_army
		hud.refresh()


func _release(world: Vector2, screen: Vector2) -> void:
	var cell := grid.world_to_cell(world)
	if hud.is_over_bench(screen):
		MatchRules.bench(_drag_army)
	else:
		MatchRules.place(player, _drag_army, cell)
	_drag_unit = null
	_drag_army = null
	changed()


## A Shard badge pressed but not yet dragged or released (see _unhandled_input).
var _pending_badge := {}
var _pending_at := Vector2.ZERO
## How far (in world pixels) the mouse moves before a pressed badge starts dragging.
const BADGE_DRAG_START := 4.0


## The item source of the Shard badge of one of your units at `world`, or {}.
func _badge_source_at(world: Vector2) -> Dictionary:
	for node in units_parent.get_children():
		var badge_owner := node as BattleUnit
		if badge_owner == null or badge_owner.team != PLAYER_TEAM or not badge_owner.has_meta("army_index"):
			continue
		var index := badge_owner.keepsake_index_at(world)
		if index >= 0:
			var source := {"from": "unit", "unit": _army_of(badge_owner), "index": index}
			var item := item_at(source)
			if item != null and (item.is_shard or table_accepts(item)):
				return source   # Keepsakes only to the ritual table, to be empowered
	return {}


func _own_unit_near(world: Vector2) -> BattleUnit:
	var best: BattleUnit = null
	var best_dist := 30.0
	for node in units_parent.get_children():
		var unit := node as BattleUnit
		if unit != null and unit.team == PLAYER_TEAM and unit.global_position.distance_to(world) < best_dist:
			best = unit
			best_dist = unit.global_position.distance_to(world)
	return best


## The figure standing for `army_unit` on the board (planning), or null.
func board_unit_of(army_unit: ArmyUnit) -> BattleUnit:
	var index := player.units.find(army_unit)
	if index == -1:
		return null
	for node in units_parent.get_children():
		var shown := node as BattleUnit
		if shown != null and shown.team == PLAYER_TEAM and shown.get_meta("army_index", -1) == index:
			return shown
	return null


func _army_of(unit: BattleUnit) -> ArmyUnit:
	return player.units[unit.get_meta("army_index")]


# ---------- Combat ----------

## The Ready button. Readying locks your army in and waits for the opponent (online it
## sends your army). The round begins only once both players are ready. Pressing it again
## while waiting un-readies you, back to planning, in case you forgot something.
func press_ready() -> void:
	if phase == Phase.WAITING:
		_unready()
		return
	if phase != Phase.PLANNING:
		return
	Sfx.play(get_tree(), Sfx.READY)
	if online:
		_submit()
		return
	_return_table()
	held = {}
	selected = null
	hud.hide_result()   # an open upgrade choice
	phase = Phase.WAITING
	_show_planning_board()
	hud.refresh()
	_try_proceed()


## Online, the joiner asked the host to un-ready and is waiting for its answer.
var _unready_pending := false


## Back from waiting to planning. Offline right away. Online the host decides when the
## round starts (it sends "go"), so the host can always take its army back; the joiner
## asks the host first, and goes back only once the host agrees (if the host has already
## started the round, its "go" arrives instead and the round goes ahead).
func _unready() -> void:
	if not online:
		_back_to_planning()
		return
	if Net.is_host():
		Net.send("unready", {"round": round_number})
		_back_to_planning()
	elif not _unready_pending:
		_unready_pending = true
		Net.send("unready_request", {"round": round_number})
		hud.refresh()


func _back_to_planning() -> void:
	phase = Phase.PLANNING
	_unready_pending = false
	_sent_army = []
	_show_planning_board()
	hud.refresh()


## Online: locks in your army as it stands and sends it to the opponent.
func _submit() -> void:
	_return_table()
	held = {}
	selected = null
	hud.hide_result()   # an open upgrade choice
	MatchRules.auto_place_bench(player)
	_sent_army = ArmyUnit.army_to_array(player.board_units())
	phase = Phase.WAITING
	Net.send("army", {"round": round_number, "army": _sent_army,
			"ascensions": ArmyUnit.ascensions_to_array(player.ascensions)})
	_show_planning_board()
	hud.refresh()
	_try_proceed()


## Once both players are ready, moves on to the fight (or, after the Opening Shop, to the
## next planning phase). Offline that's you and the computer. Online the host decides: once
## it's ready and has the joiner's army it sends "go" and starts; the joiner starts on "go".
func _try_proceed() -> void:
	if phase != Phase.WAITING:
		return
	if not online:
		if ai_ready:
			_proceed()
		return
	if not _remote_armies.has(round_number) or not Net.is_host():
		return
	Net.send("go", {"round": round_number})
	_proceed()


func _proceed() -> void:
	_unready_pending = false
	if is_opening():
		_advance_rounds()
		_begin_planning()
	else:
		_start_combat()


func _on_net_message(kind: String, data: Dictionary) -> void:
	var for_round := int(data.get("round", -1))
	match kind:
		"army":
			_remote_armies[for_round] = data["army"]
			_remote_ascensions[for_round] = data.get("ascensions", [])
			if for_round == round_number and phase in [Phase.PLANNING, Phase.WAITING]:
				ai_ready = true
				hud.refresh()
				_try_proceed()
		"go":   # host -> joiner: both are ready, the round starts
			if for_round == round_number and phase == Phase.WAITING and _remote_armies.has(for_round):
				_proceed()
		"unready":   # host -> joiner: the host took its army back
			if for_round == round_number:
				_remote_armies.erase(for_round)
				ai_ready = false
				hud.refresh()
		"unready_request":   # joiner -> host: may the joiner take its army back?
			# Only if the round hasn't started (no "go" sent): then the host forgets it.
			if for_round == round_number and phase in [Phase.PLANNING, Phase.WAITING]:
				_remote_armies.erase(for_round)
				ai_ready = false
				Net.send("unready_ok", {"round": for_round})
				hud.refresh()
		"unready_ok":   # host -> joiner: yes
			if for_round == round_number and phase == Phase.WAITING and _unready_pending:
				_back_to_planning()
		"result":   # host -> joiner
			_host_results[for_round] = data
			_try_finish_as_joiner()
		"fingerprint":   # joiner -> host
			var mine: String = _fingerprints.get(for_round, "")
			if mine != "" and mine != data["fingerprint"]:
				_warn_mismatch(for_round, mine, data["fingerprint"])


func _warn_mismatch(for_round: int, host_print: String, joiner_print: String) -> void:
	var text := "Warning: the two computers played the round %d fight differently (%s vs %s). The host's result counts." % [MatchRules.display_round(for_round), host_print, joiner_print]
	push_warning(text)
	add_log(text)
	hud.refresh()


## Online: the opponent left or the connection dropped. Whoever is left wins by forfeit.
func _on_opponent_left() -> void:
	if phase == Phase.GAME_OVER:
		return
	phase = Phase.GAME_OVER
	hud.hide_result()
	hud.show_game_over("The connection to your opponent was lost.\nYou win by forfeit.", "victory")
	hud.refresh()
	Net.leave()


## Moves on to the next round: a combat after the Opening Shop or an Encounter, an
## Encounter after a combat.
func _advance_rounds() -> void:
	round_number += 1
	if MatchRules.is_encounter_round(round_number):
		add_log("Round %d: Encounter. Choose an Ascension." % MatchRules.display_round(round_number))
	else:
		add_log("Round %d: Player Combat. Plan, then fight." % MatchRules.display_round(round_number))


# ---------- Encounters ----------

## An Encounter round: each player picks one of the Ascensions on offer. An empty offer
## (that pool has run out) skips the pick. Then on to the next combat's planning.
func _begin_encounter() -> void:
	phase = Phase.ENCOUNTER
	if is_instance_valid(_manager):   # the last combat's (its banners go with it)
		_manager.queue_free()
	_manager = null
	_clear_board()
	_fog.hide_fog()
	var number := MatchRules.encounter_number(round_number)
	var kind := MatchRules.encounter_kind(number)
	var tier := MatchRules.encounter_tier(number)
	var title := "Tier %d %s" % [tier, MatchRules.encounter_title(kind, player.faction)]
	if spectating and _blue_pick != "":   # Blue's pick already started on the result screen
		_player_picked = _blue_pick == "done"
	else:
		MatchRules.roll_ascension_offers(player, round_number)
		_player_picked = player.ascension_offers.is_empty()
	if tier > MatchRules.MAX_ASCENSION_TIER:
		add_log("No more %s Encounters: skipped." % ("Faction" if kind == MatchRules.EncounterKind.FACTION else "Neutral"))
	elif _player_picked:
		add_log("No %ss left to offer: Encounter skipped." % title)
	_start_early_picks(round_number)   # if they didn't start on the result screen
	_ai_picked = online or _ai_pick == "done"   # online, the opponent picks on their own computer
	if spectating:
		_player_picked = _blue_pick == "done" or player.ascension_offers.is_empty()
	_log_pick_summaries()
	hud.refresh()
	_picking_slot = -1
	player.ascension_reroll_cost = MatchRules.ASCENSION_REROLL_START   # resets every Encounter
	_encounter_heading = "Encounter: choose a %s" % title
	hud.show_encounter(_encounter_heading)
	_try_end_encounter()


## Starts the computer opponents' Ascension picks for the Encounter on `encounter_round`
## (offline only), unless they've started already. Called when the combat before it ends,
## so they think while you read the result, and again when the Encounter begins.
func _start_early_picks(encounter_round: int) -> void:
	if online or not MatchRules.is_encounter_round(encounter_round):
		return
	if _ai_pick == "":
		MatchRules.roll_ascension_offers(ai, encounter_round)
		if ai.ascension_offers.is_empty():
			_ai_pick = "done"
		else:
			_ai_pick = "running"
			ai_planner.pick_ascension(ai, player.last_fielded, player.last_fielded_ascensions)
	if spectating and _blue_pick == "":
		MatchRules.roll_ascension_offers(player, encounter_round)
		if player.ascension_offers.is_empty():
			_blue_pick = "done"
		else:
			_blue_pick = "running"
			_blue_planner.pick_ascension(player, ai.last_fielded, ai.last_fielded_ascensions)


## Logs what the computer opponents took, once the Encounter is on screen.
func _log_pick_summaries() -> void:
	if phase != Phase.ENCOUNTER:
		return
	for summary in [_blue_pick_summary, _ai_pick_summary]:
		if summary != "":
			add_log(summary + ".")
	_ai_pick_summary = ""
	_blue_pick_summary = ""
	hud.refresh()


## The test panel (DevPanel): an Encounter offering just `ascension`, mid-planning. The
## computer doesn't pick, and the round doesn't move on: once you've taken it you're back
## in the same planning phase.
var _dev_encounter := false

func dev_offer_ascension(ascension: Ascension) -> void:
	if phase != Phase.PLANNING:
		return
	_return_table()
	held = {}
	_dev_encounter = true
	phase = Phase.ENCOUNTER
	player.ascension_offers.assign([ascension])
	_player_picked = false
	_ai_picked = true
	_picking_slot = -1
	_clear_board()
	_encounter_heading = "Test Encounter: %s" % ascension.get_display_name()
	hud.refresh()
	hud.show_encounter(_encounter_heading)


## Rerolls one of the Encounter's Ascensions for Reserve (not in the test panel's Encounters).
func reroll_ascension(slot: int) -> void:
	if phase != Phase.ENCOUNTER or _player_picked or _picking_slot >= 0 or _dev_encounter or spectating:
		return
	var old := player.ascension_offers[slot].get_display_name() if slot >= 0 and slot < player.ascension_offers.size() else ""
	if MatchRules.reroll_ascension(player, round_number, slot):
		add_log("Rerolled %s into %s." % [old, player.ascension_offers[slot].get_display_name()])
		hud.refresh()
		hud.show_encounter(_encounter_heading)


## True if the reroll button should work right now.
func can_reroll_ascensions() -> bool:
	return phase == Phase.ENCOUNTER and not _dev_encounter and not spectating \
			and player.reserve >= player.ascension_reroll_cost and MatchRules.can_reroll_ascensions(player, round_number)


## The player's pick at an Encounter.
func choose_ascension(slot: int) -> void:
	if phase != Phase.ENCOUNTER or _player_picked or spectating:
		return
	if slot >= 0 and slot < player.ascension_offers.size() and player.ascension_offers[slot].is_chosen():
		_begin_unit_pick(slot)
		return
	if MatchRules.take_ascension(player, slot):
		_player_picked = true
		add_log("You took %s." % player.ascensions[-1].get_display_name())
		hud.hide_encounter()
		hud.refresh()
		_try_end_encounter()


## A chosen-unit Ascension: the cards make way for your army on the board, and you click
## the unit that gets it (bench units are listed in the banner). Units that can't take it
## are dimmed.
func _begin_unit_pick(slot: int) -> void:
	_picking_slot = slot
	_pick_choice = null
	var ascension := player.ascension_offers[slot]
	hud.hide_encounter()
	_clear_board()
	for unit in ArmySpawner.spawn(player.units, PLAYER_TEAM, false, units_parent, player.ascensions):
		if not ascension.can_pick(_army_of(unit)):
			unit.modulate = Color(1, 1, 1, 0.35)
	var bench := player.bench_units().filter(func(u): return ascension.can_pick(u))
	hud.show_unit_pick(ascension, bench)


## Gives the Ascension being picked for to `unit` (one of your army units).
func pick_unit(unit: ArmyUnit) -> void:
	if phase != Phase.ENCOUNTER or _picking_slot < 0:
		return
	var index := player.units.find(unit)
	if not MatchRules.take_ascension(player, _picking_slot, index):
		return
	_picking_slot = -1
	_pick_choice = null
	_player_picked = true
	add_log("You took %s for %s." % [player.ascensions[-1].get_display_name(), unit.label().strip_edges()])
	hud.hide_unit_pick()
	_clear_board()
	hud.refresh()
	_try_end_encounter()


## Back from picking a unit to the Encounter's cards.
func cancel_unit_pick() -> void:
	if phase != Phase.ENCOUNTER or _picking_slot < 0:
		return
	_picking_slot = -1
	_pick_choice = null
	hud.hide_unit_pick()
	_clear_board()
	hud.show_encounter(_encounter_heading)


func _try_end_encounter() -> void:
	if phase != Phase.ENCOUNTER or not (_player_picked and _ai_picked):
		return
	if _dev_encounter:   # a test Encounter: back to the same planning phase
		_dev_encounter = false
		hud.hide_encounter()
		phase = Phase.PLANNING
		changed()
		return
	_ai_pick = ""
	_blue_pick = ""
	hud.hide_encounter()
	_advance_rounds()
	_begin_planning()


## Seconds of countdown before each fight (see _start_combat).
const COMBAT_COUNTDOWN := 3.0
## How many Ascensions each player had at their last combat, so the countdown can show
## only the ones picked since (at the Encounter just before this combat).
var _ascensions_seen := {}   # PlayerState -> count


## The Ascensions `p` picked since its last combat (usually none, or the one from the
## Encounter just before), and remembers its count for next time.
func _new_ascensions(p: PlayerState) -> Array[Ascension]:
	var seen: int = _ascensions_seen.get(p, 0)
	var fresh: Array[Ascension] = []
	for i in range(seen, p.ascensions.size()):
		fresh.append(p.ascensions[i])
	_ascensions_seen[p] = p.ascensions.size()
	return fresh


func _start_combat() -> void:
	phase = Phase.COMBAT
	_fight_over = false
	var bottom: Array[ArmyUnit]   # team 1
	var top: Array[ArmyUnit]      # team 2, on the far side
	var bottom_ascensions: Array[Ascension] = player.ascensions
	var top_ascensions: Array[Ascension] = ai.ascensions
	var combat_seed := -1
	if online:
		# Both computers build the fight from exactly the same text: the host's army as
		# team 1, the joiner's as team 2, and a seed from the match and the round.
		var mine := ArmyUnit.army_from_array(_sent_army)
		var theirs := ArmyUnit.army_from_array(_remote_armies[round_number])
		player.last_fielded = ArmyUnit.copy_army(mine)
		ai.last_fielded = ArmyUnit.copy_army(theirs)
		ai.units = ArmyUnit.copy_army(theirs)
		ai.ascensions = ArmyUnit.ascensions_from_array(_remote_ascensions.get(round_number, []))
		bottom = mine if Net.is_host() else theirs
		top = theirs if Net.is_host() else mine
		bottom_ascensions = player.ascensions if Net.is_host() else ai.ascensions
		top_ascensions = ai.ascensions if Net.is_host() else player.ascensions
		combat_seed = hash([Net.match_seed, round_number]) & 0x7fffffff
	else:
		for p in [player, ai]:
			MatchRules.auto_place_bench(p)
			p.last_fielded = ArmyUnit.copy_army(p.board_units())
		bottom = player.units
		top = ai.units
	for p in [player, ai]:
		p.last_fielded_round = round_number
		p.last_fielded_ascensions = p.ascensions.duplicate()
	_clear_board()
	_fog.hide_fog()
	# Placeholder faction borders around each half (team 1 is the host's army online).
	var player_bottom := not online or Net.is_host()
	grid.team_factions = {PLAYER_TEAM: player.faction if player_bottom else ai.faction,
			ENEMY_TEAM: ai.faction if player_bottom else player.faction}
	_frame_camera(my_team != PLAYER_TEAM)   # the joiner watches it turned around
	ArmySpawner.spawn(bottom, PLAYER_TEAM, false, units_parent, bottom_ascensions)
	ArmySpawner.spawn(top, ENEMY_TEAM, true, units_parent, top_ascensions)
	damage_tracker.set_team_titles({my_team: player.player_name, 3 - my_team: ai.player_name}, my_team != PLAYER_TEAM)
	damage_tracker.set_planning(false)
	hud.refresh()
	# A short countdown before the fight, over the board, with the Ascension each player
	# picked at the Encounter just before this combat (if there was one). Only this match
	# scene waits: sims and the computer's planning copies fight straight away. Online
	# both games wait the same way and then play the same fight, so they still agree.
	var my_picks := _new_ascensions(player)
	var their_picks := _new_ascensions(ai)
	hud.show_combat_intro(player.player_name, my_picks, ai.player_name, their_picks, COMBAT_COUNTDOWN)
	await get_tree().create_timer(COMBAT_COUNTDOWN).timeout
	if not is_inside_tree() or phase != Phase.COMBAT:
		return
	hud.finish_combat_intro()   # "GAMBIT", fading out as the fight starts
	await get_tree().physics_frame   # let every unit finish _ready
	if is_instance_valid(_manager):
		_manager.queue_free()
	_manager = BattleManager.new()
	_manager.auto_start = false
	_manager.damage_tracker = damage_tracker
	_manager.combat_seed = combat_seed
	add_child(_manager)
	_manager.battle_ended.connect(_on_battle_ended)
	_manager.overtime_started.connect(combat_music.on_overtime)   # keeps the music's overtime part on time
	_combat_time = 0.0
	# Music first: a fight that ends the moment it starts (an empty army) then stops it.
	combat_music.play(combat_track_override if combat_track_override != null else CombatMusic.pick(music_faction()))
	_manager.start_battle()


## Whose combat music plays in fights: your faction's (each faction can have its own tracks;
## see CombatMusic.pick). Change this to pick by something else, such as the opponent.
func music_faction() -> String:
	return player.faction


func _physics_process(delta: float) -> void:
	if phase != Phase.COMBAT or _manager == null or _fight_over:
		return
	if _manager.overtime_after > 0.0 and not _manager.in_overtime:
		combat_music.tick(_manager.overtime_after - _manager.combat_time)   # the build-up into overtime
	_combat_time += delta
	if _combat_time > COMBAT_HARD_LIMIT and _manager.phase == BattleManager.Phase.COMBAT:
		push_warning("Combat passed %ds; ending it as a draw." % COMBAT_HARD_LIMIT)
		_manager.phase = BattleManager.Phase.RESULT
		for node in get_tree().get_nodes_in_group("units"):
			(node as BattleUnit).stop_combat()
		_on_battle_ended(-1)


## The fight on this computer is over. Offline (and for the host) that settles it; the
## joiner waits for the host's result, which counts.
func _on_battle_ended(winner: int) -> void:
	if phase != Phase.COMBAT or _fight_over:
		return
	_fight_over = true
	combat_music.stop()   # fades out over the result
	_keep_match_gains()
	var result := {"round": round_number, "winner": winner,
			"aura_1": ArmySpawner.surviving_aura(get_tree(), PLAYER_TEAM),
			"aura_2": ArmySpawner.surviving_aura(get_tree(), ENEMY_TEAM),
			"fingerprint": BattleArena.fingerprint(get_tree(), roundi(_manager.combat_time * 60.0))}
	_my_fingerprint = result["fingerprint"]
	if online:   # for checking both computers saw the same fight
		print("Round %d fight: winner %d, fingerprint %s" % [MatchRules.display_round(round_number), winner, _my_fingerprint])
	if not online:
		_apply_result(result)
	elif Net.is_host():
		_fingerprints[round_number] = _my_fingerprint
		Net.send("result", result)
		_apply_result(result)
	else:
		Net.send("fingerprint", {"round": round_number, "fingerprint": _my_fingerprint})
		if not _host_results.has(round_number):
			add_log("Fight over. Waiting for the host's result...")
			hud.refresh()
		_try_finish_as_joiner()


## Writes what units gained for the rest of the match this fight (Codger B) back to the
## armies they came from. Offline both armies were spawned from player.units and ai.units.
## Online only our own side is ours to change: it was spawned from the army we sent (our
## board units, in order); the other player keeps theirs and sends it with their next army.
func _keep_match_gains() -> void:
	var gains := ArmySpawner.collect_match_gains(get_tree())
	if gains.is_empty():
		return
	if not online:
		ArmySpawner.apply_match_gains(player.units, gains.get(PLAYER_TEAM, {}))
		ArmySpawner.apply_match_gains(ai.units, gains.get(ENEMY_TEAM, {}))
		player.reserve += ArmySpawner.reserve_from(gains, PLAYER_TEAM)   # Von Carrow's bounty
		ai.reserve += ArmySpawner.reserve_from(gains, ENEMY_TEAM)
		player.inventory.append_array(ArmySpawner.shards_from(gains, PLAYER_TEAM))   # Shred A2
		ai.inventory.append_array(ArmySpawner.shards_from(gains, ENEMY_TEAM))
		return
	var mine := PLAYER_TEAM if Net.is_host() else ENEMY_TEAM
	ArmySpawner.apply_match_gains(player.board_units(), gains.get(mine, {}))
	player.reserve += ArmySpawner.reserve_from(gains, mine)
	player.inventory.append_array(ArmySpawner.shards_from(gains, mine))


func _try_finish_as_joiner() -> void:
	if phase != Phase.COMBAT or not _fight_over or not _host_results.has(round_number):
		return
	var result: Dictionary = _host_results[round_number]
	if result["fingerprint"] != _my_fingerprint:
		_warn_mismatch(round_number, result["fingerprint"], _my_fingerprint)
	_apply_result(result)


## Damage and income from a fight's result: {winner (team, or -1 for a draw), aura_1,
## aura_2 (each team's surviving Aura)}.
func _apply_result(result: Dictionary) -> void:
	if spectating:
		_apply_spectate_result(result)
		return
	phase = Phase.RESULT
	var winner := int(result["winner"])
	var other_team := 3 - my_team
	var mine := int(result["aura_%d" % my_team])
	var theirs := int(result["aura_%d" % other_team])
	var lines: PackedStringArray = []
	# For the damage animation: health before, and each side's orb (true = yours).
	var hp_before := {true: player.hp, false: ai.hp}
	var hits: Array = []
	if winner == my_team:
		var damage := MatchRules.loss_damage(round_number, mine)
		hits.append(_damage_hit(true, my_team, damage, ai.hp - damage))
		ai.hp -= damage
		lines.append("You won! %d Aura of your units survived." % mine)
		lines.append("Opponent takes %d damage (%d for round %d + %d for survivors)." % [damage, MatchRules.round_damage(round_number), MatchRules.display_round(round_number), MatchRules.survivor_damage(mine)])
	elif winner == other_team:
		var damage := MatchRules.loss_damage(round_number, theirs)
		hits.append(_damage_hit(false, other_team, damage, player.hp - damage))
		player.hp -= damage
		lines.append("You lost. %d Aura of their units survived." % theirs)
		lines.append("You take %d damage (%d for round %d + %d for survivors)." % [damage, MatchRules.round_damage(round_number), MatchRules.display_round(round_number), MatchRules.survivor_damage(theirs)])
	else:
		var to_player := MatchRules.draw_damage(round_number, theirs)
		var to_ai := MatchRules.draw_damage(round_number, mine)
		hits.append(_damage_hit(true, my_team, to_ai, ai.hp - to_ai))
		hits.append(_damage_hit(false, other_team, to_player, player.hp - to_player))
		player.hp -= to_player
		ai.hp -= to_ai
		lines.append("Draw. You take %d damage, the opponent takes %d." % [to_player, to_ai])
	for p in [player, ai]:
		var paid := MatchRules.pay_income(p, round_number)
		if p == player:
			lines.append("Income: +%d Aura, +%d Reserve." % [paid["aura"], paid["reserve"]])
			_round_income = paid   # for the next Round Announcement
	combats_done += 1
	add_log("Round %d combat: %s" % [MatchRules.display_round(round_number), lines[0]])
	if player.is_alive() and ai.is_alive():
		_start_early_picks(round_number + 1)
	# The pips and orb first (the health bars hold their old values until it hits), then
	# the result. The Continue button only appears with the result, so nothing moves on.
	hud.hold_health(hp_before)
	hud.refresh()
	await hud.play_damage(hits)
	if not player.is_alive() or not ai.is_alive():
		continue_after_result()   # the killing orb shattered a bar: straight to victory or defeat
		return
	hud.show_result("\n".join(lines))
	hud.refresh()


## One side's damage orb for the HUD: `from_mine` says whose it is, `team` their battle
## team (for the surviving units' pips), `damage` the total it deals, `hp_after` the
## target's health once it lands.
func _damage_hit(from_mine: bool, team: int, damage: int, hp_after: int) -> Dictionary:
	var survivors := []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team == team and not unit.is_summon and unit.get_aura_value() > 0:
			survivors.append({"at": unit.get_global_transform_with_canvas().origin, "aura": unit.get_aura_value()})
	return {"from_mine": from_mine, "round_damage": MatchRules.round_damage(round_number),
			"survivors": survivors, "damage": damage, "hp_after": hp_after}


## The Continue button after a combat: back to your board, or the end of the match.
func continue_after_result() -> void:
	if phase != Phase.RESULT:
		return
	hud.hide_result()
	if not player.is_alive() or not ai.is_alive():
		phase = Phase.GAME_OVER
		var text := ""   # the big VICTORY / DEFEAT / DRAW sign says it all
		var outcome := "draw"
		if player.is_alive():
			outcome = "victory"
		elif ai.is_alive():
			outcome = "defeat"
		if spectating:
			text = "Both computers fell. It's a draw."
			if player.is_alive() or ai.is_alive():
				var champ := player if player.is_alive() else ai
				text = "%s wins the match with %d HP left!" % [champ.player_name, champ.hp]
			_spectate_write("%s  (%d combats)\n" % [text, combats_done])
			outcome = ""   # no sign when watching two computers
		hud.show_game_over(text, outcome)
		hud.refresh()
		if online:
			Net.leave()
		if spectating:
			await get_tree().create_timer(SPECTATE_GAME_OVER_PAUSE).timeout
			if is_inside_tree() and spectating:
				new_match()
		return
	_advance_rounds()
	_begin_encounter()


# ---------- Watching two computers ----------

func _setup_spectating() -> void:
	player.player_name = "Blue"
	ai.player_name = "Red"
	player.is_ai = true
	ai.is_ai = true
	ai_planner.label = "Red"
	ai_planner.plan_ready.connect(_on_ai_plan_ready)
	_blue_planner = AiPlanner.new()
	_blue_planner.label = "Blue"
	add_child(_blue_planner)
	_blue_planner.plan_ready.connect(_on_blue_plan_ready)
	spectate_match_number += 1
	_spectate_write("=== Match %d (%s) ===" % [spectate_match_number, Time.get_datetime_string_from_system(false, true)])


func _on_blue_plan_ready(summary: String) -> void:
	if _blue_pick == "running":
		_blue_pick = "done"
		_blue_pick_summary = summary
		if phase == Phase.ENCOUNTER:
			_player_picked = true
			_log_pick_summaries()
			_try_end_encounter()
		return
	_blue_ready = true
	add_log(summary + ".")
	hud.refresh()
	_spectate_try_fight()


var _spectate_starting := false

## Once both computers have planned: shows both armies for a moment, then fights.
func _spectate_try_fight() -> void:
	if not (ai_ready and _blue_ready) or phase != Phase.PLANNING or _spectate_starting:
		return
	_spectate_starting = true
	for p in [player, ai]:
		MatchRules.auto_place_bench(p)
	_clear_board()
	_fog.hide_fog()
	ArmySpawner.spawn(player.units, PLAYER_TEAM, false, units_parent, player.ascensions)
	ArmySpawner.spawn(ai.units, ENEMY_TEAM, true, units_parent, ai.ascensions)
	await get_tree().create_timer(SPECTATE_BOARD_PAUSE).timeout
	_spectate_starting = false
	if is_inside_tree() and phase == Phase.PLANNING:
		press_ready()


func _apply_spectate_result(result: Dictionary) -> void:
	phase = Phase.RESULT
	var winner := int(result["winner"])
	var aura := {PLAYER_TEAM: int(result["aura_1"]), ENEMY_TEAM: int(result["aura_2"])}
	var sides := {PLAYER_TEAM: player, ENEMY_TEAM: ai}
	var lines: PackedStringArray = []
	# For the damage animation, as in a played match (blue's bar is the bottom one).
	var hp_before := {true: player.hp, false: ai.hp}
	var hits: Array = []
	if winner == PLAYER_TEAM or winner == ENEMY_TEAM:
		var loser: PlayerState = sides[3 - winner]
		var damage := MatchRules.loss_damage(round_number, aura[winner])
		hits.append(_damage_hit(winner == PLAYER_TEAM, winner, damage, loser.hp - damage))
		loser.hp -= damage
		lines.append("%s won with %d Aura surviving. %s takes %d damage." % [sides[winner].player_name, aura[winner], loser.player_name, damage])
	else:
		var to_blue := MatchRules.draw_damage(round_number, aura[ENEMY_TEAM])
		var to_red := MatchRules.draw_damage(round_number, aura[PLAYER_TEAM])
		hits.append(_damage_hit(true, PLAYER_TEAM, to_red, ai.hp - to_red))
		hits.append(_damage_hit(false, ENEMY_TEAM, to_blue, player.hp - to_blue))
		player.hp -= to_blue
		ai.hp -= to_red
		lines.append("Draw. Blue takes %d damage, Red takes %d." % [to_blue, to_red])
	lines.append("HP: Blue %d, Red %d." % [maxi(player.hp, 0), maxi(ai.hp, 0)])
	for p in [player, ai]:
		MatchRules.pay_income(p, round_number)
	combats_done += 1
	if player.is_alive() and ai.is_alive():
		_start_early_picks(round_number + 1)
	add_log("Round %d: %s" % [MatchRules.display_round(round_number), lines[0]])
	_spectate_write("Round %d (%.0fs fight)\n  Blue: %s\n  Red:  %s\n  %s %s" % [MatchRules.display_round(round_number), _combat_time,
			_army_text(player.last_fielded), _army_text(ai.last_fielded), lines[0], lines[1]])
	# The pips and orb first (the bars hold their old values until it hits), then the result.
	hud.hold_health(hp_before)
	hud.refresh()
	await hud.play_damage(hits)
	if not is_inside_tree():
		return
	if not player.is_alive() or not ai.is_alive():
		continue_after_result()   # a killing orb shattered a bar: straight to the end
		return
	hud.show_result("\n".join(lines))
	hud.refresh()
	await get_tree().create_timer(SPECTATE_RESULT_PAUSE).timeout
	if is_inside_tree() and phase == Phase.RESULT:
		continue_after_result()


## "Garth A1 [Wrack Shard, Blizzard], Silt ..." for the log.
static func _army_text(army: Array[ArmyUnit]) -> String:
	var parts := PackedStringArray()
	for unit in army:
		var text := unit.label().strip_edges()
		if unit.buffs > 0:
			text += " +%d buffs" % unit.buffs
		if not unit.items.is_empty():
			text += " [%s]" % ", ".join(unit.items.map(func(k): return k.get_display_name()))
		parts.append(text)
	return ", ".join(parts)


## Adds lines to the watching log (see SPECTATE_LOG).
static func _spectate_write(text: String) -> void:
	var file := FileAccess.open(SPECTATE_LOG, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(SPECTATE_LOG, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(text)
	file.close()


## Leaves the match for the main menu, from the Escape menu or after the match. Online,
## the connection is closed, so the opponent wins by forfeit if the match was still going.
## Background copies the computer was planning with stop with the planner (see AiPlanner).
func return_to_menu() -> void:
	Engine.time_scale = 1.0
	MatchGame.spectating = false
	if Net.is_online():
		Net.leave()
	get_tree().change_scene_to_file(MENU_SCENE)


## After the match: online back to the menu, otherwise a fresh match against the computer.
func new_match() -> void:
	if online:
		Net.leave()
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		get_tree().reload_current_scene()


## Leaving the match, however it ends: close the computer's background copies.
func _exit_tree() -> void:
	AiPool.stop()
