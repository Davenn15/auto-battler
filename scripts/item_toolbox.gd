class_name ItemToolbox
extends PanelContainer
## Testing tool: hand any keepsake or Shard to any unit before a fight. Click a unit to
## select it (the UnitInfoPanel does the selecting), then click an item below to equip it.
## Click one of the unit's equipped items to take it off again; it simply goes away.
## Items can only change before the fight starts: their effects start with the battle.

## The panel whose selection this follows. Found automatically if left empty.
@export var info_panel: UnitInfoPanel
@export_dir var keepsakes_dir: String = "res://data/keepsakes"

const BUTTON_SIZE := Vector2(26, 26)
const COLUMNS := 8

var _unit: BattleUnit = null
var _locked := false   # true once the selected unit is fighting
var _body: VBoxContainer
var _status: Label
var _equipped_row: HBoxContainer
var _item_buttons: Array[Button] = []
var _toggle: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # clicks on the panel don't reach the board
	# Sit in the bottom-right corner and grow up and to the left as the content needs.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build()
	if info_panel == null:
		info_panel = _find_info_panel(get_tree().root)
	if info_panel == null:
		push_warning("ItemToolbox: no UnitInfoPanel in the scene, so units can't be selected.")
	else:
		info_panel.unit_selected.connect(_on_unit_selected)
	_refresh()


func _process(_delta: float) -> void:
	# Notice the selected unit dying or the fight starting, which the panel doesn't announce.
	if _unit != null and not is_instance_valid(_unit):
		_unit = null
		_refresh()
	elif _unit != null and _unit.active != _locked:
		_refresh()


# ---------- Building the panel ----------

func _build() -> void:
	var column := VBoxContainer.new()
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Item toolbox"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_toggle = Button.new()
	_toggle.text = "Hide"
	_toggle.pressed.connect(_on_toggle_pressed)
	header.add_child(_toggle)

	_body = VBoxContainer.new()
	column.add_child(_body)
	_status = _small_label("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(COLUMNS * (BUTTON_SIZE.x + 4), 0)
	_body.add_child(_status)

	_body.add_child(_small_label("Equipped (click to remove):"))
	_equipped_row = HBoxContainer.new()
	_equipped_row.custom_minimum_size = Vector2(0, BUTTON_SIZE.y)
	_body.add_child(_equipped_row)

	_body.add_child(_small_label("Toolbox (click to equip):"))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	_body.add_child(grid)
	var pools := RandomTeams.load_keepsakes(keepsakes_dir)
	var items: Array = pools["shards"] + pools["keepsakes"]
	items.sort_custom(_item_order)
	for keepsake in items:
		var button := _item_button(keepsake)
		button.pressed.connect(_on_item_pressed.bind(keepsake))
		grid.add_child(button)
		_item_buttons.append(button)


## Shards first, then keepsakes grouped by their first Shard, then their second.
static func _item_order(a: Keepsake, b: Keepsake) -> bool:
	if a.is_shard != b.is_shard:
		return a.is_shard
	if a.first_shard != b.first_shard:
		return a.first_shard < b.first_shard
	return a.second_shard < b.second_shard


func _item_button(keepsake: Keepsake) -> Button:
	var button := Button.new()
	button.icon = keepsake.get_icon()
	button.expand_icon = true
	button.custom_minimum_size = BUTTON_SIZE
	button.tooltip_text = describe(keepsake)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	return label


func _find_info_panel(node: Node) -> UnitInfoPanel:
	if node == null:
		return null
	if node is UnitInfoPanel:
		return node
	for child in node.get_children():
		var found := _find_info_panel(child)
		if found != null:
			return found
	return null


## The text shown when hovering an item: its name, its stats, then its effect.
static func describe(keepsake: Keepsake) -> String:
	var lines: PackedStringArray = [keepsake.get_display_name()]
	var bonuses := keepsake.get_stat_bonuses()
	for stat in bonuses:
		var amount: float = bonuses[stat]
		if is_zero_approx(amount):
			continue
		var stat_name: String = Stats.STAT_NAMES.get(stat, str(stat))
		if stat in [Stats.Stat.WRACK_CHANCE, Stats.Stat.WRACK_DAMAGE, Stats.Stat.VAMPIRISM]:
			lines.append("+%s%% %s" % [_number(amount * 100.0), stat_name])
		else:
			lines.append("+%s %s" % [_number(amount), stat_name])
	if not is_zero_approx(keepsake.health):
		lines.append("+%s Health" % _number(keepsake.health))
	if keepsake.description != "":
		lines.append(keepsake.description)
	lines.append("(%d Reserve)" % keepsake.get_reserve_value())
	return "\n".join(lines)


## "20" for whole numbers, "2.5" otherwise.
static func _number(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	return str(int(rounded)) if is_equal_approx(rounded, roundf(rounded)) else str(rounded)


# ---------- Reacting to clicks ----------

func _on_unit_selected(unit: BattleUnit) -> void:
	_unit = unit
	_refresh()


func _on_item_pressed(keepsake: Keepsake) -> void:
	if _unit != null and not _unit.active:
		_unit.equip(keepsake)
		_refresh()


func _on_equipped_pressed(keepsake: Keepsake) -> void:
	if _unit != null and not _unit.active:
		_unit.unequip(keepsake)   # back in the toolbox, which always has every item
		_refresh()


func _on_toggle_pressed() -> void:
	_body.visible = not _body.visible
	_toggle.text = "Hide" if _body.visible else "Show"


## Redraws the status line and the equipped row, and enables the item buttons only when
## the selected unit can take another item.
func _refresh() -> void:
	_locked = _unit != null and _unit.active
	for child in _equipped_row.get_children():
		child.queue_free()

	var can_equip := false
	if _unit == null:
		_status.text = "Click a unit to give it items."
	else:
		var unit_name := _unit.data.display_name.capitalize() if _unit.data != null else str(_unit.name)
		var count := _unit.keepsakes.size()
		_status.text = "%s (team %d): %d / %d items" % [unit_name, _unit.team, count, BattleUnit.MAX_KEEPSAKES]
		if _locked:
			_status.text += "\nThe fight has started; items can't change now."
		elif count >= BattleUnit.MAX_KEEPSAKES:
			_status.text += "\nFull: remove an item to add another."
		can_equip = not _locked and count < BattleUnit.MAX_KEEPSAKES
		for keepsake in _unit.keepsakes:
			var button := _item_button(keepsake)
			button.disabled = _locked
			button.pressed.connect(_on_equipped_pressed.bind(keepsake))
			_equipped_row.add_child(button)

	for button in _item_buttons:
		button.disabled = not can_equip
