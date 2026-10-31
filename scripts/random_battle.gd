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
@export_dir var units_dir: String = "res://data/units"

@onready var battle_manager: BattleManager = $"Battle Manager"
@onready var grid: BattleGrid = $BattleGrid
@onready var units_parent: Node = $BattleUnits
@onready var fight_button: Button = $CanvasLayer/UI/FightButton
@onready var reroll_button: Button = $CanvasLayer/UI/RerollButton
@onready var lineup_label: Label = $CanvasLayer/UI/LineupLabel


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
	var teams := {
		1: RandomTeams.make_team(roster, arv, max_team, allow_duplicates),
		2: RandomTeams.make_team(roster, arv, max_team, allow_duplicates),
	}
	if teams[1].is_empty() or teams[2].is_empty():
		lineup_label.text = "Couldn't build two teams worth exactly %d ARV. Try another range." % arv
		fight_button.disabled = true
		return
	var placement := RandomTeams.place_teams(grid, teams)
	var lines: PackedStringArray = ["ARV %d    seed %d" % [arv, used_seed]]
	for team in teams:
		var names: PackedStringArray = []
		for i in teams[team].size():
			var pick: Dictionary = teams[team][i]
			_spawn(pick, team, placement[team][i])
			names.append("%s %s" % [pick["data"].display_name.capitalize(), RandomTeams.path_label(pick["path"])])
		lines.append("Team %d: %s" % [team, ", ".join(names)])
	lineup_label.text = "\n".join(lines)


func _spawn(pick: Dictionary, team: int, cell: Vector2i) -> void:
	var unit := UNIT_SCENE.instantiate() as BattleUnit
	unit.data = pick["data"]
	unit.team = team
	unit.upgrade_path.assign(pick["path"])
	unit.auto_place = false   # placed below, instead of snapping to where it was created
	units_parent.add_child(unit)
	unit.place_at(cell)


func _on_fight_pressed() -> void:
	fight_button.disabled = true
	battle_manager.start_battle()


func _on_battle_ended(winning_team: int) -> void:
	lineup_label.text += "\nWinner: team %d" % winning_team if winning_team > 0 else "\nDraw"
