class_name ArvDisplay
extends PanelContainer
## Shows each team's ARV, a rough at-a-glance measure of strength, with the Aura and Reserve
## it has spent.

var _labels: Dictionary = {}   # team -> Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	add_child(column)
	for team in DamageTracker.TEAM_COLORS:
		var label := Label.new()
		label.add_theme_color_override("font_color", DamageTracker.TEAM_COLORS[team])
		column.add_child(label)
		_labels[team] = label


## Recounted every frame, so it updates as units are placed, moved, or removed.
func _process(_delta: float) -> void:
	var units := get_tree().get_nodes_in_group("units")
	for team in _labels:
		var value := Economy.team_value(units, team)
		var team_name: String = DamageTracker.TEAM_NAMES.get(team, "Team %d" % team)
		_labels[team].text = "%s   ARV %d   (Aura %d, Reserve %d)" % [
				team_name, value["total"], value["aura"], value["reserve"]]
