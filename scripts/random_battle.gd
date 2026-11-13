extends Node2D
## Test scene: two random teams of equal ARV, placed like a player would. Press Fight to
## watch them, or New teams to roll again.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## Each team's ARV is picked from this range. Set both the same for a fixed value.
@export var arv_min: int = 10
@export var arv_max: int = 16
@export var max_team: int = 8
@export var allow_duplicates: bool = false
## 0 rolls new teams every time. Any other number always rolls the same teams.
@export var team_seed: int = 0
## Start fighting as soon as the teams are placed.
@export var auto_fight: bool = false
## Every team gets at least one front-liner (a unit whose Placement is Front on its path).
@export var require_frontline: bool = true
## Each team is built from a single faction (picked at random, or from its first forced
## unit). Off mixes every faction into both teams.
@export var isolate_factions: bool = true
## Reserve each team spends on random keepsakes and Shards, per point of ARV: 1 = as much
## Reserve as Aura, 0 = no items. Rounded down to whole Shards. The balance sim uses it too.
@export_range(0.0, 3.0, 0.25) var reserve_scale: float = 1.0
@export_dir var units_dir: String = "res://data/units"
@export_dir var keepsakes_dir: String = "res://data/keepsakes"
## Units each team always gets, filled out randomly after them. One per entry: a name,
## optionally followed by a path, like "merribold b", "garth a1", "silt base" or just
## "wesper" for a random path. If they cost more than the rolled ARV, the ARV goes up.
@export var team_1_units: Array[String] = []
@export var team_2_units: Array[String] = []

@onready var battle_manager: BattleManager = $"Battle Manager"
@onready var grid: BattleGrid = $BattleGrid
@onready var units_parent: Node = $BattleUnits
@onready var fight_button: Button = $CanvasLayer/UI/FightButton
@onready var reroll_button: Button = $CanvasLayer/UI/RerollButton
@onready var lineup_panel: LineupPanel = $CanvasLayer/UI/LineupPanel


func _ready() -> void:
	fight_button.pressed.connect(_on_fight_pressed)
	reroll_button.pressed.connect(get_tree().reload_current_scene)
	battle_manager.battle_ended.connect(_on_battle_ended)
	var used_seed := team_seed if team_seed != 0 else randi()
	seed(used_seed)
	_spawn_teams(randi_range(arv_min, arv_max), used_seed)
	if auto_fight and not fight_button.disabled:
		await get_tree().physics_frame   # let the new units finish _ready
		_on_fight_pressed()


func _spawn_teams(arv: int, used_seed: int) -> void:
	var roster := RandomTeams.load_roster(units_dir)
	var forced := {1: [], 2: []}
	var errors: PackedStringArray = []
	for team in forced:
		for text in (team_1_units if team == 1 else team_2_units):
			var wanted := RandomTeams.parse_pick(roster, text)
			if wanted.has("error"):
				errors.append("Team %d: %s" % [team, wanted["error"]])
			else:
				forced[team].append(wanted)
		arv = maxi(arv, RandomTeams.min_cost(forced[team]))
	if not errors.is_empty():
		lineup_panel.set_message("\n".join(errors), Color(1.0, 0.5, 0.5))
		fight_button.disabled = true
		return

	var pools := RandomTeams.load_keepsakes(keepsakes_dir)
	var reserve := RandomTeams.reserve_budget(arv, reserve_scale)
	var teams := {}
	var loadouts := {}
	for team in forced:
		var pool := RandomTeams.team_roster(roster, isolate_factions, forced[team])
		teams[team] = RandomTeams.make_team(pool, arv, max_team, allow_duplicates, require_frontline,
				forced[team])
		loadouts[team] = RandomTeams.buy_keepsakes(pools, reserve, teams[team].size(), BattleUnit.MAX_KEEPSAKES)
	if teams[1].is_empty() or teams[2].is_empty():
		lineup_panel.set_message("Couldn't build two teams worth exactly %d ARV. Try another range." % arv, Color(1.0, 0.5, 0.5))
		fight_button.disabled = true
		return
	var placement := RandomTeams.place_teams(grid, teams)
	lineup_panel.set_header("ARV %d    seed %d" % [arv, used_seed])
	for team in teams:
		for i in teams[team].size():
			_spawn(teams[team][i], team, placement[team][i], loadouts[team][i])
	# The lineup panel lists the units itself, reading them from the board.


func _spawn(pick: Dictionary, team: int, cell: Vector2i, keepsakes: Array = []) -> void:
	var unit := UNIT_SCENE.instantiate() as BattleUnit
	unit.data = pick["data"]
	unit.team = team
	unit.upgrade_path.assign(pick["path"])
	unit.auto_place = false   # placed below, instead of snapping to where it was created
	units_parent.add_child(unit)
	for keepsake in keepsakes:   # after add_child: equip recomputes health from the data
		unit.equip(keepsake)
	unit.place_at(cell)


func _on_fight_pressed() -> void:
	fight_button.disabled = true
	battle_manager.start_battle()


func _on_battle_ended(winning_team: int) -> void:
	if winning_team > 0:
		lineup_panel.set_message("Winner: team %d" % winning_team, DamageTracker.TEAM_COLORS.get(winning_team, Color.WHITE))
	else:
		lineup_panel.set_message("Draw")
