class_name MatchGame
extends Node2D
## A match: you against the computer, or online against another player (see Net). Runs
## the rounds (Opening Shop, then Encounter and Player Combat in turn), the planning phase
## (shop, placing units, items, the ritual table), the combats, damage and income. The
## screen panels are MatchHud.
##
## Online, each player shops on their own computer and sends their finished army when
## they're ready (or when the planning time runs out). Both computers then play the same
## fight from the same armies and seed: the host's army as team 1 at the bottom, the
## joiner's as team 2 on the far side. The joiner watches it turned around so their own
## army is at the bottom. The host's result counts; each side also sends a fingerprint of
## how the fight ended, so any difference gets noticed.

## WAITING: online, your army is sent and you're waiting for the opponent's.
enum Phase { PLANNING, WAITING, COMBAT, RESULT, GAME_OVER }

const PLAYER_TEAM := 1
const ENEMY_TEAM := 2
## Safety net: a combat still running after this many seconds ends as a draw.
## Overtime is meant to make sure this never happens.
const COMBAT_HARD_LIMIT := 180.0
const BOARD_SCREEN_CENTER := Vector2(555, 330)   # where the board's centre sits on screen
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
@onready var ai_planner: AiPlanner = $AiPlanner

var player := PlayerState.new()
var ai := PlayerState.new()
var round_number := 1
var combats_done := 0
var phase: Phase = Phase.PLANNING
var ai_ready := false
var log_lines: PackedStringArray = []

## What the mouse is holding: {} nothing, {"item": inventory index} or {"bench": ArmyUnit}.
var held: Dictionary = {}
## The unit whose items are listed in the panel.
var selected: ArmyUnit = null
## The ritual table's two slots: Shards taken out of the inventory, or null.
var table: Array = [null, null]

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

## Factions picked in the menu: yours (Blue's when watching) and the computer's (Red's).
## Online, the opponent's comes from Net instead.
static var player_faction := MatchRules.DEFAULT_FACTION
static var opponent_faction := MatchRules.DEFAULT_FACTION


func _ready() -> void:
	# A background test copy that booted straight into a match (the main scene isn't the
	# menu): go to the tester instead of playing.
	if AiPlanner.is_eval_copy():
		get_tree().change_scene_to_file.call_deferred("res://scenes/ai_eval.tscn")
		return
	player.player_name = "You"
	ai.player_name = "Opponent"
	online = Net.is_online()
	player.faction = player_faction
	ai.faction = Net.opponent_faction if online else opponent_faction
	if spectating:
		_setup_spectating()
	elif online:
		my_team = PLAYER_TEAM if Net.is_host() else ENEMY_TEAM
		Net.message.connect(_on_net_message)
		Net.opponent_left.connect(_on_opponent_left)
	else:
		ai.is_ai = true
		ai_planner.plan_ready.connect(_on_ai_plan_ready)
	_fog = MatchFog.new()
	_fog.z_index = 30
	add_child(_fog)
	_frame_camera()
	hud.game = self
	add_log("Round 1: Opening Shop. Spend your starting Aura and Reserve.")
	_begin_planning()


## Centres the board where the panels leave room for it. `turned` looks at it rotated half
## a turn (the joiner watching the host's fight), with units and labels turned to match.
func _frame_camera(turned: bool = false) -> void:
	var box := Rect2(grid.cell_to_world(MatchRules.own_cells()[0]), Vector2.ZERO)
	for cell in MatchRules.own_cells():
		box = box.expand(grid.cell_to_world(cell)).expand(grid.cell_to_world(MatchRules.mirror_cell(cell)))
	var screen_center := get_viewport_rect().size / 2.0
	var shift := (screen_center - BOARD_SCREEN_CENTER) / camera.zoom
	camera.ignore_rotation = false
	camera.rotation = PI if turned else 0.0
	camera.position = box.get_center() + (-shift if turned else shift)
	BattleUnit.view_rotation = PI if turned else 0.0
	BattleUnit.swap_team_colors = my_team != PLAYER_TEAM and turned
	grid.queue_redraw()   # the board tint follows the colour swap


func combat_number() -> int:
	return combats_done + 1


func is_opening() -> bool:
	return round_number == 1


func add_log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 6:
		log_lines.remove_at(0)


# ---------- Planning ----------

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
	damage_tracker.visible = false
	_show_planning_board()
	if online:
		ai_ready = _remote_armies.has(round_number)   # they may have finished already
		planning_left = PLANNING_TIME
		hud.refresh()
		return
	ai_ready = false
	hud.refresh()
	# The opponent plans against the army you last fielded, just as you see theirs.
	ai_planner.plan(ai, player.last_fielded, combat_number())
	if spectating:
		_blue_ready = false
		_blue_planner.plan(player, ai.last_fielded, combat_number())


## Online: counts down the planning time, then readies you with the board as it stands.
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
	ai_ready = true
	add_log(summary + ".")
	if spectating:
		_spectate_try_fight()
	hud.refresh()


## Your army on your half; the opponent's last fielded army under the fog on theirs.
func _show_planning_board() -> void:
	_clear_board()
	for unit in ArmySpawner.spawn(player.units, PLAYER_TEAM, false, units_parent):
		var rally := RallyPassive.aura_range(unit)   # Lunck's aura reach, to plan around
		if rally >= 0:
			KeepsakeVfx.rally_aura(unit, rally, RallyPassive.aura_gives_insight(unit))
	for unit in ArmySpawner.spawn(ai.last_fielded, ENEMY_TEAM, true, units_parent):
		unit.modulate.a = 0.6
	_fog.show_fog(grid, ai.faction, ai.last_fielded_round)


func _clear_board() -> void:
	for child in units_parent.get_children():
		units_parent.remove_child(child)
		child.queue_free()
	grid.clear_occupants()


## Rebuilds the board and the panels after anything in the planning phase changes.
func changed() -> void:
	if phase == Phase.PLANNING:
		_show_planning_board()
	hud.refresh()


func buy_unit(slot: int, choice: int = -1) -> void:
	if phase != Phase.PLANNING:
		return
	var data := player.unit_offers[slot]
	if MatchRules.buy_unit_offer(player, slot, choice):
		var info := player.find_unit(data)
		add_log("Bought %s." % (info.label() if info != null else data.display_name))
	changed()


func buy_shard(slot: int) -> void:
	if phase == Phase.PLANNING and MatchRules.buy_shard_offer(player, slot):
		changed()


## Rerolls the units and the Shards together.
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


## Puts the held Shard on the ritual table, or takes a Shard off it.
func table_clicked(slot: int) -> void:
	if table[slot] != null:
		player.inventory.append(table[slot])
		table[slot] = null
	elif held.has("item") and player.inventory[held["item"]].is_shard:
		table[slot] = player.inventory[held["item"]]
		player.inventory.remove_at(held["item"])
		held = {}
	changed()


func table_preview() -> Keepsake:
	return MatchRules.combine_result(table[0], table[1])


func combine_table() -> void:
	var result := table_preview()
	if result == null:
		return
	player.inventory.append(result)
	table = [null, null]
	add_log("The ritual made %s." % result.get_display_name())
	changed()


func _return_table() -> void:
	for slot in 2:
		if table[slot] != null:
			player.inventory.append(table[slot])
			table[slot] = null


# ---------- Moving units on the board ----------

func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.PLANNING or spectating:
		return
	var world := get_global_mouse_position()
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		held = {}
		hud.refresh()
		return
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press(world)
		elif _drag_unit != null:
			_release(world, button.position)
	elif event is InputEventMouseMotion and _drag_unit != null:
		_drag_unit.global_position = world


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


func _own_unit_near(world: Vector2) -> BattleUnit:
	var best: BattleUnit = null
	var best_dist := 30.0
	for node in units_parent.get_children():
		var unit := node as BattleUnit
		if unit != null and unit.team == PLAYER_TEAM and unit.global_position.distance_to(world) < best_dist:
			best = unit
			best_dist = unit.global_position.distance_to(world)
	return best


func _army_of(unit: BattleUnit) -> ArmyUnit:
	return player.units[unit.get_meta("army_index")]


# ---------- Combat ----------

## The Ready / Fight button. Online it sends your army and waits for the opponent's.
func press_ready() -> void:
	if phase != Phase.PLANNING:
		return
	if online:
		_submit()
		return
	if not ai_ready:
		return
	_return_table()
	held = {}
	if is_opening():
		_advance_rounds()
		_begin_planning()
	else:
		_start_combat()


## Online: locks in your army as it stands and sends it to the opponent.
func _submit() -> void:
	_return_table()
	held = {}
	selected = null
	hud.hide_result()   # an open upgrade choice
	MatchRules.auto_place_bench(player)
	_sent_army = ArmyUnit.army_to_array(player.board_units())
	phase = Phase.WAITING
	Net.send("army", {"round": round_number, "army": _sent_army})
	_show_planning_board()
	hud.refresh()
	_try_proceed()


## Online: once both armies for this round are in, moves on to the fight (or, after the
## Opening Shop, to the next planning phase).
func _try_proceed() -> void:
	if phase != Phase.WAITING or not _remote_armies.has(round_number):
		return
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
			if for_round == round_number and phase in [Phase.PLANNING, Phase.WAITING]:
				ai_ready = true
				hud.refresh()
				_try_proceed()
		"result":   # host -> joiner
			_host_results[for_round] = data
			_try_finish_as_joiner()
		"fingerprint":   # joiner -> host
			var mine: String = _fingerprints.get(for_round, "")
			if mine != "" and mine != data["fingerprint"]:
				_warn_mismatch(for_round, mine, data["fingerprint"])


func _warn_mismatch(for_round: int, host_print: String, joiner_print: String) -> void:
	var text := "Warning: the two computers played the round %d fight differently (%s vs %s). The host's result counts." % [for_round, host_print, joiner_print]
	push_warning(text)
	add_log(text)
	hud.refresh()


## Online: the opponent left or the connection dropped. Whoever is left wins by forfeit.
func _on_opponent_left() -> void:
	if phase == Phase.GAME_OVER:
		return
	phase = Phase.GAME_OVER
	hud.hide_result()
	hud.show_game_over("The connection to your opponent was lost.\nYou win by forfeit.")
	hud.refresh()
	Net.leave()


## Moves on from the round just played, past the (skipped for now) Encounter round, to
## the next combat round.
func _advance_rounds() -> void:
	round_number += 1
	add_log("Round %d: Encounter (skipped for now)." % round_number)
	round_number += 1
	add_log("Round %d: Player Combat. Plan, then fight." % round_number)


func _start_combat() -> void:
	phase = Phase.COMBAT
	_fight_over = false
	var bottom: Array[ArmyUnit]   # team 1
	var top: Array[ArmyUnit]      # team 2, on the far side
	var combat_seed := -1
	if online:
		# Both computers build the fight from exactly the same text: the host's army as
		# team 1, the joiner's as team 2, and a seed from the match and the round.
		var mine := ArmyUnit.army_from_array(_sent_army)
		var theirs := ArmyUnit.army_from_array(_remote_armies[round_number])
		player.last_fielded = ArmyUnit.copy_army(mine)
		ai.last_fielded = ArmyUnit.copy_army(theirs)
		ai.units = ArmyUnit.copy_army(theirs)
		bottom = mine if Net.is_host() else theirs
		top = theirs if Net.is_host() else mine
		combat_seed = hash([Net.match_seed, round_number]) & 0x7fffffff
	else:
		for p in [player, ai]:
			MatchRules.auto_place_bench(p)
			p.last_fielded = ArmyUnit.copy_army(p.board_units())
		bottom = player.units
		top = ai.units
	for p in [player, ai]:
		p.last_fielded_round = round_number
	_clear_board()
	_fog.hide_fog()
	_frame_camera(my_team != PLAYER_TEAM)   # the joiner watches it turned around
	ArmySpawner.spawn(bottom, PLAYER_TEAM, false, units_parent)
	ArmySpawner.spawn(top, ENEMY_TEAM, true, units_parent)
	damage_tracker.set_team_titles({my_team: player.player_name, 3 - my_team: ai.player_name}, my_team != PLAYER_TEAM)
	damage_tracker.visible = true
	hud.refresh()
	await get_tree().physics_frame   # let every unit finish _ready
	if is_instance_valid(_manager):
		_manager.queue_free()
	_manager = BattleManager.new()
	_manager.auto_start = false
	_manager.damage_tracker = damage_tracker
	_manager.combat_seed = combat_seed
	add_child(_manager)
	_manager.battle_ended.connect(_on_battle_ended)
	_combat_time = 0.0
	_manager.start_battle()


func _physics_process(delta: float) -> void:
	if phase != Phase.COMBAT or _manager == null or _fight_over:
		return
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
	var result := {"round": round_number, "winner": winner,
			"aura_1": ArmySpawner.surviving_aura(get_tree(), PLAYER_TEAM),
			"aura_2": ArmySpawner.surviving_aura(get_tree(), ENEMY_TEAM),
			"fingerprint": BattleArena.fingerprint(get_tree(), roundi(_manager.combat_time * 60.0))}
	_my_fingerprint = result["fingerprint"]
	print("Round %d fight: winner %d, fingerprint %s" % [round_number, winner, _my_fingerprint])
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
	if winner == my_team:
		var damage := MatchRules.loss_damage(round_number, mine)
		ai.hp -= damage
		lines.append("You won! %d Aura of your units survived." % mine)
		lines.append("Opponent takes %d damage (%d for round %d + %d for survivors)." % [damage, MatchRules.round_damage(round_number), round_number, mine / 2])
	elif winner == other_team:
		var damage := MatchRules.loss_damage(round_number, theirs)
		player.hp -= damage
		lines.append("You lost. %d Aura of their units survived." % theirs)
		lines.append("You take %d damage (%d for round %d + %d for survivors)." % [damage, MatchRules.round_damage(round_number), round_number, theirs / 2])
	else:
		var to_player := MatchRules.draw_damage(round_number, theirs)
		var to_ai := MatchRules.draw_damage(round_number, mine)
		player.hp -= to_player
		ai.hp -= to_ai
		lines.append("Draw. You take %d damage, the opponent takes %d." % [to_player, to_ai])
	for p in [player, ai]:
		var paid := MatchRules.pay_income(p, round_number)
		if p == player:
			lines.append("Income: +%d Aura, +%d Reserve." % [paid["aura"], paid["reserve"]])
	combats_done += 1
	add_log("Round %d combat: %s" % [round_number, lines[0]])
	hud.show_result("\n".join(lines))
	hud.refresh()


## The Continue button after a combat: back to your board, or the end of the match.
func continue_after_result() -> void:
	if phase != Phase.RESULT:
		return
	hud.hide_result()
	if not player.is_alive() or not ai.is_alive():
		phase = Phase.GAME_OVER
		var text := "Both players fell. It's a draw."
		if player.is_alive():
			text = "You win the match!"
		elif ai.is_alive():
			text = "You were defeated."
		if spectating:
			text = "Both computers fell. It's a draw."
			if player.is_alive() or ai.is_alive():
				var champ := player if player.is_alive() else ai
				text = "%s wins the match with %d HP left!" % [champ.player_name, champ.hp]
			_spectate_write("%s  (%d combats)\n" % [text, combats_done])
		hud.show_game_over(text)
		hud.refresh()
		if online:
			Net.leave()
		if spectating:
			await get_tree().create_timer(SPECTATE_GAME_OVER_PAUSE).timeout
			if is_inside_tree() and spectating:
				new_match()
		return
	_advance_rounds()
	_begin_planning()


# ---------- Watching two computers ----------

func _setup_spectating() -> void:
	player.player_name = "Blue"
	ai.player_name = "Red"
	player.is_ai = true
	ai.is_ai = true
	ai_planner.label = "Red"
	ai_planner.plan_ready.connect(_on_ai_plan_ready)
	_blue_planner = AiPlanner.new()
	_blue_planner.job_prefix = "blue_job"
	_blue_planner.label = "Blue"
	add_child(_blue_planner)
	_blue_planner.plan_ready.connect(_on_blue_plan_ready)
	spectate_match_number += 1
	_spectate_write("=== Match %d (%s) ===" % [spectate_match_number, Time.get_datetime_string_from_system(false, true)])


func _on_blue_plan_ready(summary: String) -> void:
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
	ArmySpawner.spawn(player.units, PLAYER_TEAM, false, units_parent)
	ArmySpawner.spawn(ai.units, ENEMY_TEAM, true, units_parent)
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
	if winner == PLAYER_TEAM or winner == ENEMY_TEAM:
		var loser: PlayerState = sides[3 - winner]
		var damage := MatchRules.loss_damage(round_number, aura[winner])
		loser.hp -= damage
		lines.append("%s won with %d Aura surviving. %s takes %d damage." % [sides[winner].player_name, aura[winner], loser.player_name, damage])
	else:
		var to_blue := MatchRules.draw_damage(round_number, aura[ENEMY_TEAM])
		var to_red := MatchRules.draw_damage(round_number, aura[PLAYER_TEAM])
		player.hp -= to_blue
		ai.hp -= to_red
		lines.append("Draw. Blue takes %d damage, Red takes %d." % [to_blue, to_red])
	lines.append("HP: Blue %d, Red %d." % [maxi(player.hp, 0), maxi(ai.hp, 0)])
	for p in [player, ai]:
		MatchRules.pay_income(p, round_number)
	combats_done += 1
	add_log("Round %d: %s" % [round_number, lines[0]])
	_spectate_write("Round %d (%.0fs fight)\n  Blue: %s\n  Red:  %s\n  %s %s" % [round_number, _combat_time,
			_army_text(player.last_fielded), _army_text(ai.last_fielded), lines[0], lines[1]])
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


## After the match: online back to the menu, otherwise a fresh match against the computer.
func new_match() -> void:
	if online:
		Net.leave()
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		get_tree().reload_current_scene()
