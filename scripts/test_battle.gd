extends Node2D

@onready var battle_manager: BattleManager = $"Battle Manager"
@onready var fight_button : Button = $CanvasLayer/UI/FightButton

@export var prep: Node

func _ready() -> void:
	fight_button.pressed.connect(_on_fight_pressed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	
	fight_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fight_button.position.y -= 40


func _on_fight_pressed() -> void:
	prep.prep_enabled = false
	fight_button.disabled = true
	battle_manager.start_battle()

func _on_battle_ended(winning_team: int) -> void:
	print("Battle over. Winner: team %d" % winning_team)
