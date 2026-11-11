class_name MatchHud
extends Control
## The match screen's panels: a top bar (round, health and money), the planning panel on
## the right (shop, bench, items, the selected unit), the ritual table's own window, the
## log and the
## Ready / Fight button under the board, and pop-ups for upgrades, results and the end.
## Everything is rebuilt from the MatchGame's state by refresh().

const SIDE_WIDTH := 330.0
const ICON := Vector2(26, 26)
const HELD_COLOR := Color(1.0, 0.85, 0.3)
const FRAME_COLOR := Color(0.09, 0.09, 0.11, 0.92)
const BORDER_COLOR := Color(0.38, 0.38, 0.44)

var game: MatchGame

var _top: RichTextLabel
var _side: PanelContainer
var _shop_units: VBoxContainer
var _shop_shards: HBoxContainer
var _reroll: Button
var _lock: Button
var _bench_box: PanelContainer
var _bench: HFlowContainer
var _inventory: HFlowContainer
var _sell: Button
var _selected_label: Label
var _selected_items: HBoxContainer
var _table_window: PanelContainer
var _board_drop: Control
var _table_slots: Array[Button] = []
var _table_result: TextureRect
var _items_box: PanelContainer
var _combine: Button
var _hint: Label
var _log: Label
var _ready_button: Button
var _popup: PanelContainer
var _popup_text: Label
var _popup_buttons: VBoxContainer
var _unit_tip: PanelContainer
var _unit_tip_text: RichTextLabel
var _spectate_bar: HBoxContainer
var _speed_button: Button

const SPEEDS := [1.0, 2.0, 4.0]

const UNIT_TIP_WIDTH := 320.0

## Size of the ritual table's slots and result, in pixels.
const TABLE_SLOT := 36.0
## Size of a unit's picture on the bench.
const BENCH_TILE := Vector2(58, 70)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_side()
	_build_table_window()
	_build_board_drop()
	_build_bottom()
	_build_popup()
	_build_unit_tip()
	_build_spectate_bar()


## Watching two computers: a game-speed toggle and a way back to the menu, under the board.
func _build_spectate_bar() -> void:
	_spectate_bar = HBoxContainer.new()
	_spectate_bar.add_theme_constant_override("separation", 10)
	_spectate_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_spectate_bar.offset_left = 440 - 576
	_spectate_bar.offset_right = 670 - 576
	_spectate_bar.offset_top = -50
	_spectate_bar.offset_bottom = -10
	_spectate_bar.visible = false
	add_child(_spectate_bar)
	_speed_button = Button.new()
	_speed_button.custom_minimum_size = Vector2(110, 0)
	_speed_button.add_theme_font_size_override("font_size", 16)
	_speed_button.tooltip_text = "How fast the game runs while you watch."
	_speed_button.pressed.connect(_cycle_speed)
	_spectate_bar.add_child(_speed_button)
	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(110, 0)
	menu.add_theme_font_size_override("font_size", 16)
	menu.pressed.connect(_leave_spectating)
	_spectate_bar.add_child(menu)
	_show_speed()


func _cycle_speed() -> void:
	var i := SPEEDS.find(Engine.time_scale)
	Engine.time_scale = SPEEDS[(i + 1) % SPEEDS.size()]
	_show_speed()


func _show_speed() -> void:
	_speed_button.text = "Speed %dx" % roundi(Engine.time_scale)


func _leave_spectating() -> void:
	Engine.time_scale = 1.0
	MatchGame.spectating = false
	get_tree().change_scene_to_file(MatchGame.MENU_SCENE)


## The panel that shows what a shop unit does while the mouse is over it.
func _build_unit_tip() -> void:
	_unit_tip = PanelContainer.new()
	_unit_tip.add_theme_stylebox_override("panel", _frame(10))
	_unit_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_tip.visible = false
	add_child(_unit_tip)
	_unit_tip_text = RichTextLabel.new()
	_unit_tip_text.bbcode_enabled = true
	_unit_tip_text.fit_content = true
	_unit_tip_text.scroll_active = false
	_unit_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_tip_text.custom_minimum_size = Vector2(UNIT_TIP_WIDTH, 0)
	_unit_tip_text.add_theme_font_size_override("normal_font_size", 13)
	_unit_tip_text.add_theme_font_size_override("bold_font_size", 13)
	_unit_tip.add_child(_unit_tip_text)


## Shows the unit popup beside the shop, level with `button`.
func show_unit_tip(button: Control, data: UnitData) -> void:
	_unit_tip_text.text = describe_shop_unit(data, game.player.find_unit(data))
	_unit_tip.visible = true
	_unit_tip.reset_size()
	var top := clampf(button.global_position.y, 40.0, size.y - _unit_tip.size.y - 8.0)
	_unit_tip.position = Vector2(_side.global_position.x - _unit_tip.size.x - 8.0, top)


func hide_unit_tip() -> void:
	_unit_tip.visible = false


## What a shop unit does: its passives and Gambit (as you have it, if you own it), and
## what buying it would do next (an upgrade's choices, or a stat buff).
static func describe_shop_unit(data: UnitData, owned: ArmyUnit) -> String:
	var passives: Array = data.passives.duplicate()
	var gambit: Gambit = data.gambit
	var chosen: Array[Upgrade] = []
	if owned != null:
		var choices := data.upgrades
		for pick in owned.path:
			if pick < 0 or pick >= choices.size():
				break
			chosen.append(choices[pick])
			choices = choices[pick].next_choices
	for upgrade in chosen:
		passives.append_array(upgrade.passives)
		if upgrade.gambit != null:
			gambit = upgrade.gambit
	var lines := PackedStringArray()
	var title := "[b]%s[/b]   [color=#9a9aa5]tier %d[/color]" % [data.display_name.capitalize(), data.tier]
	if owned != null:
		title += "   [color=#66a6ff]yours: %s[/color]" % owned.label()
	lines.append(title)
	for passive in passives:
		lines.append(_ability_text("Passive", UnitInfoPanel._ability_name(passive, passive.passive_name, "Passive"), passive.description))
	if gambit != null:
		lines.append(_ability_text("Gambit", UnitInfoPanel._ability_name(gambit, gambit.gambit_name, "Gambit"), gambit.description))
	if owned != null and not owned.is_maxed():
		lines.append("")
		lines.append("[b]Buying it upgrades yours. Choose one:[/b]")
		for choice in MatchRules.upgrade_choices(owned):
			var path := owned.path.duplicate()
			path.append(choice["index"])
			lines.append("[color=#ffd24d]%s[/color]  %s" % [RandomTeams.path_label(path), describe_upgrade(choice["upgrade"]).replace("\n", " ")])
	elif owned != null:
		lines.append("")
		lines.append("[b]Yours is fully upgraded:[/b] buying it buffs its stats.")
	return "\n".join(lines)


static func _ability_text(kind: String, ability_name: String, description: String) -> String:
	var line := "[b]%s:[/b] %s" % [kind, ability_name]
	if description != "":
		line += "\n[color=#cccccc]%s[/color]" % description
	return line


# ---------- Building ----------

func _frame(margin: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(margin)
	return style


func _label(text: String, font_size: int = 12, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text.length() > 12 else TextServer.AUTOWRAP_OFF
	return label


func _header(text: String) -> Label:
	return _label(text, 13, Color(0.85, 0.85, 0.9))


func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _frame(4))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 30
	add_child(bar)
	_top = RichTextLabel.new()
	_top.bbcode_enabled = true
	_top.fit_content = true
	_top.scroll_active = false
	_top.add_theme_font_size_override("normal_font_size", 14)
	_top.add_theme_font_size_override("bold_font_size", 14)
	bar.add_child(_top)


func _build_side() -> void:
	_side = PanelContainer.new()
	_side.add_theme_stylebox_override("panel", _frame())
	_side.anchor_left = 1.0
	_side.anchor_right = 1.0
	_side.anchor_bottom = 1.0
	_side.offset_left = -SIDE_WIDTH - 6
	_side.offset_right = -6
	_side.offset_top = 36
	_side.offset_bottom = -6
	add_child(_side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(scroll)
	# The ritual table follows the Items list when the panel scrolls or the window resizes.
	scroll.get_v_scroll_bar().value_changed.connect(func(_value): _place_table_window())
	resized.connect(_place_table_window)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)

	# Shop
	column.add_child(_header("Shop"))
	_shop_units = VBoxContainer.new()
	column.add_child(_shop_units)
	_shop_shards = HBoxContainer.new()
	column.add_child(_shop_shards)
	var rerolls := HBoxContainer.new()
	column.add_child(rerolls)
	_reroll = Button.new()
	_reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll.pressed.connect(func(): game.reroll())
	rerolls.add_child(_reroll)
	_lock = Button.new()
	_lock.toggle_mode = true
	_lock.custom_minimum_size = Vector2(90, 0)
	_lock.tooltip_text = "Keep this shop for your next planning phase instead of a fresh one.\nUnlocks itself once that phase starts."
	_lock.pressed.connect(func(): game.toggle_shop_lock())
	rerolls.add_child(_lock)
	column.add_child(HSeparator.new())

	# Bench
	_bench_box = PanelContainer.new()
	var bench_style := StyleBoxFlat.new()
	bench_style.bg_color = Color(1, 1, 1, 0.04)
	bench_style.set_content_margin_all(4)
	_bench_box.add_theme_stylebox_override("panel", bench_style)
	column.add_child(_bench_box)
	var bench_column := VBoxContainer.new()
	_bench_box.add_child(bench_column)
	bench_column.add_child(_header("Bench"))
	bench_column.add_child(_label("Drag units between here and the board, or click one, then a cell.", 10, Color(0.65, 0.65, 0.7)))
	_bench = HFlowContainer.new()
	bench_column.add_child(_bench)
	column.add_child(HSeparator.new())

	# Items: dropping an item anywhere in this box sends it to the inventory.
	_items_box = PanelContainer.new()
	_items_box.add_theme_stylebox_override("panel", bench_style)
	_accept_drops(_items_box, func(): return {"to": "inventory"})
	_items_box.item_rect_changed.connect(_place_table_window)   # the table stays level with it
	column.add_child(_items_box)
	var items_column := VBoxContainer.new()
	_items_box.add_child(items_column)
	items_column.add_child(_header("Items"))
	items_column.add_child(_label("Drag items between here, your units and the ritual table, or click one to hold it.", 10, Color(0.65, 0.65, 0.7)))
	_inventory = HFlowContainer.new()
	items_column.add_child(_inventory)
	_sell = Button.new()
	_sell.pressed.connect(func(): game.sell_held())
	items_column.add_child(_sell)
	column.add_child(HSeparator.new())

	# Selected unit
	_selected_label = _label("", 12)
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_selected_label)
	_selected_items = HBoxContainer.new()
	column.add_child(_selected_items)


## The ritual table: its own narrow box, hanging off the side panel's left edge level with
## the Items list. Two slots stacked, what they make, and Combine.
func _build_table_window() -> void:
	_table_window = PanelContainer.new()
	var style := _frame(6)
	style.corner_radius_top_right = 0      # joins the side panel on that side
	style.corner_radius_bottom_right = 0
	_table_window.add_theme_stylebox_override("panel", style)
	add_child(_table_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_table_window.add_child(column)
	var title := _label("Ritual", 12, Color(0.85, 0.85, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for slot in 2:
		if slot == 1:
			column.add_child(_centered_label("+"))
		var button := Button.new()
		button.custom_minimum_size = Vector2(TABLE_SLOT, TABLE_SLOT)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.expand_icon = true
		button.pressed.connect(func(): game.table_clicked(slot))
		_wire_item(button, func(): return {"from": "table", "slot": slot}, func(): return {"to": "table", "slot": slot})
		column.add_child(button)
		_table_slots.append(button)
	column.add_child(_centered_label("="))
	_table_result = TextureRect.new()
	_table_result.custom_minimum_size = Vector2(TABLE_SLOT, TABLE_SLOT)
	_table_result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_table_result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_table_result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_table_result)
	_combine = Button.new()
	_combine.text = "Combine"
	_combine.add_theme_font_size_override("font_size", 11)
	_combine.pressed.connect(func(): game.combine_table())
	column.add_child(_combine)


func _centered_label(text: String) -> Label:
	var label := _label(text, 13, Color(0.7, 0.7, 0.75))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Keeps the ritual table against the side panel's left edge, level with the Items list.
func _place_table_window() -> void:
	if _table_window == null or not _table_window.visible:
		return
	_table_window.reset_size()
	var top := clampf(_items_box.global_position.y, 40.0, size.y - _table_window.size.y - 8.0)
	_table_window.position = Vector2(_side.global_position.x - _table_window.size.x + 2.0, top)


## Catches drops on the board: an item equips the unit under the mouse, a bench unit is
## placed on the cell under the mouse. It only takes the mouse while something is being
## dragged, so clicks still reach the board.
func _build_board_drop() -> void:
	_board_drop = Control.new()
	_board_drop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_drop)
	move_child(_board_drop, 0)   # under every panel
	_board_drop.set_drag_forwarding(Callable(), _board_can_drop, _board_dropped)


func _board_can_drop(at: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("bench_unit"):
		return game.can_place_at_screen(at)
	return _can_drop_at(at, data, _board_dest)


func _board_dropped(at: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("bench_unit"):
		game.place_at_screen(data["bench_unit"], at)
	else:
		_drop_at(at, data, _board_dest)


## A bench unit dragged out to the board, shown as its picture.
func _bench_drag(_at: Vector2, unit: ArmyUnit) -> Variant:
	if game.phase != MatchGame.Phase.PLANNING:
		return null
	var picture := TextureRect.new()
	picture.texture = unit.data.sprite
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size = Vector2(48, 48)
	picture.position = Vector2(-24, -24)
	picture.modulate = Color(1, 1, 1, 0.85)
	var holder := Control.new()
	holder.add_child(picture)
	set_drag_preview(holder)
	return {"bench_unit": unit}


func _notification(what: int) -> void:
	if _board_drop == null:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		_board_drop.mouse_filter = Control.MOUSE_FILTER_STOP
	elif what == NOTIFICATION_DRAG_END:
		_board_drop.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---------- Dragging items ----------

## Lets `control` be dragged as the item `source()` returns (a MatchGame item source, or {}
## for nothing to drag), and dropped on as `dest()` (a MatchGame item destination, or {}).
## Either callable may be null.
func _wire_item(control: Control, source: Callable, dest: Callable) -> void:
	control.set_drag_forwarding(_item_drag.bind(control, source), _can_drop_at.bind(dest), _drop_at.bind(dest))


## Lets `control` only take drops, as `dest()` (or `dest(at)` for the board).
func _accept_drops(control: Control, dest: Callable) -> void:
	control.set_drag_forwarding(Callable(), _can_drop_at.bind(dest), _drop_at.bind(dest))


func _item_drag(_at: Vector2, control: Control, source: Callable) -> Variant:
	if not source.is_valid():
		return null
	var from: Dictionary = source.call()
	var item := game.item_at(from) if not from.is_empty() else null
	if item == null or (from["from"] == "unit" and not item.is_shard):
		return null
	control.set_drag_preview(_drag_preview(item))
	return {"item_source": from}


func _can_drop_at(at: Vector2, data: Variant, dest: Callable) -> bool:
	return dest.is_valid() and _can_drop(data, _call_dest(dest, at))


func _drop_at(at: Vector2, data: Variant, dest: Callable) -> void:
	if dest.is_valid() and _can_drop(data, _call_dest(dest, at)):
		game.move_item(data["item_source"], _call_dest(dest, at))


func _call_dest(dest: Callable, at: Vector2) -> Dictionary:
	return dest.call(at) if dest.get_argument_count() == 1 else dest.call()


func _can_drop(data: Variant, dest: Dictionary) -> bool:
	return data is Dictionary and data.has("item_source") and not dest.is_empty() \
			and game.can_move_item(data["item_source"], dest)


func _unit_dest(unit: ArmyUnit) -> Dictionary:
	return {"to": "unit", "unit": unit}


## The board: the unit under the mouse, if it's yours.
func _board_dest(at: Vector2) -> Dictionary:
	var unit := game.own_army_unit_at_screen(at)
	return {"to": "unit", "unit": unit} if unit != null else {}


## Starts dragging an item from somewhere that isn't a panel, like a badge on the board.
func start_item_drag(source: Dictionary) -> void:
	var item := game.item_at(source)
	if item != null:
		force_drag({"item_source": source}, _drag_preview(item))


func _drag_preview(item: Keepsake) -> Control:
	var icon := TextureRect.new()
	icon.texture = item.get_icon()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(32, 32)
	icon.position = Vector2(-16, -16)
	icon.modulate = Color(1, 1, 1, 0.85)
	var holder := Control.new()   # so the icon sits centred on the mouse
	holder.add_child(icon)
	return holder


func _build_bottom() -> void:
	_hint = _label("", 12, HELD_COLOR)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_left = 330 - 576
	_hint.offset_right = 780 - 576
	_hint.offset_top = 36
	_hint.offset_bottom = 56
	add_child(_hint)

	_log = _label("", 11, Color(0.8, 0.8, 0.84))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.anchor_top = 1.0
	_log.anchor_bottom = 1.0
	_log.offset_left = 8
	_log.offset_right = 470
	_log.offset_top = -112
	_log.offset_bottom = -6
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log)

	_ready_button = Button.new()
	_ready_button.add_theme_font_size_override("font_size", 18)
	_ready_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ready_button.offset_left = 480 - 576
	_ready_button.offset_right = 630 - 576
	_ready_button.offset_top = -50
	_ready_button.offset_bottom = -10
	_ready_button.pressed.connect(func(): game.press_ready())
	add_child(_ready_button)


func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.add_theme_stylebox_override("panel", _frame(14))
	_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_popup.custom_minimum_size = Vector2(380, 0)
	_popup.visible = false
	add_child(_popup)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_popup.add_child(column)
	_popup_text = _label("", 14)
	column.add_child(_popup_text)
	_popup_buttons = VBoxContainer.new()
	column.add_child(_popup_buttons)


## Shows the pop-up with `text` and one button per [label, callable].
func _show_popup(text: String, buttons: Array) -> void:
	_popup_text.text = text
	for child in _popup_buttons.get_children():
		child.queue_free()
	for entry in buttons:
		var button := Button.new()
		button.text = entry[0]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(entry[1])
		_popup_buttons.add_child(button)
	_popup.visible = true
	_popup.reset_size()
	_popup.position = MatchGame.BOARD_SCREEN_CENTER - _popup.size / 2.0


func hide_result() -> void:
	_popup.visible = false


func show_result(text: String) -> void:
	_show_popup(text, [["Continue", func(): game.continue_after_result()]])


func show_game_over(text: String) -> void:
	_show_popup(text, [["New match", func(): game.new_match()]])


func _show_upgrade_choice(slot: int, unit: ArmyUnit) -> void:
	var buttons := []
	for choice in MatchRules.upgrade_choices(unit):
		var upgrade: Upgrade = choice["upgrade"]
		var path := unit.path.duplicate()
		path.append(choice["index"])
		buttons.append(["%s: %s" % [RandomTeams.path_label(path), describe_upgrade(upgrade)],
				_pick_upgrade.bind(slot, choice["index"])])
	buttons.append(["Cancel", func(): hide_result()])
	_show_popup("Choose %s's upgrade:" % unit.display_name(), buttons)


## An upgrade's name and description if it has them; otherwise what it changes, read from
## its data (new passives, a new Gambit, Gambit bonuses, range).
static func describe_upgrade(upgrade: Upgrade) -> String:
	var parts: PackedStringArray = []
	if upgrade.upgrade_name != "Upgrade" and upgrade.upgrade_name != "":
		parts.append(upgrade.upgrade_name)
	if upgrade.description != "":
		parts.append(upgrade.description)
	if not parts.is_empty():
		return "\n".join(parts)
	for passive in upgrade.passives:
		var line := passive.passive_name if passive.passive_name != "Passive" else passive.resource_path.get_file().get_basename().capitalize()
		parts.append(line + (": " + passive.description if passive.description != "" else ""))
	if upgrade.gambit != null:
		var gambit_name := upgrade.gambit.gambit_name
		if gambit_name == "Gambit":
			gambit_name = upgrade.gambit.resource_path.get_file().get_basename().capitalize()
		parts.append("New Gambit: " + gambit_name)
	for property in upgrade.gambit_bonuses:
		parts.append("Gambit %s %+g" % [property.capitalize(), upgrade.gambit_bonuses[property]])
	for property in upgrade.gambit_overrides:
		parts.append("Gambit %s = %g" % [property.capitalize(), upgrade.gambit_overrides[property]])
	if upgrade.attack_range_bonus != 0:
		parts.append("Attack range %+d" % upgrade.attack_range_bonus)
	parts.append("Stats grow with the upgrade level")
	return "\n".join(parts)


func _pick_upgrade(slot: int, choice: int) -> void:
	hide_result()
	game.buy_unit(slot, choice)


func is_over_bench(screen_point: Vector2) -> bool:
	return _side.visible and _bench_box.get_global_rect().has_point(screen_point)


# ---------- Filling in ----------

func refresh() -> void:
	if game == null:
		return
	hide_unit_tip()   # the shop buttons are about to be rebuilt
	var planning := game.phase == MatchGame.Phase.PLANNING and not MatchGame.spectating
	_side.visible = planning
	_table_window.visible = planning
	_hint.visible = planning
	_spectate_bar.visible = MatchGame.spectating
	_refresh_top()
	_log.text = "\n".join(game.log_lines)
	var waiting := game.phase == MatchGame.Phase.WAITING
	_ready_button.visible = planning or waiting
	if game.online:
		# Online you can ready up any time; then you wait for the opponent.
		_ready_button.disabled = waiting
		_ready_button.text = "Waiting for opponent..." if waiting else ("Done" if game.is_opening() else "Fight!")
	else:
		_ready_button.disabled = not game.ai_ready
		_ready_button.text = ("Done" if game.is_opening() else "Fight!") if game.ai_ready else "Opponent planning..."
	if not planning:
		return
	_refresh_shop()
	_refresh_bench()
	_refresh_items()
	_refresh_selected()
	_refresh_table()
	_refresh_hint()


## Just the top bar, e.g. for the planning countdown.
func refresh_top() -> void:
	if game != null:
		_refresh_top()


func _refresh_top() -> void:
	var p := game.player
	var phase_name := "Opening Shop" if game.is_opening() else "Player Combat"
	var choosing := game.phase in [MatchGame.Phase.PLANNING, MatchGame.Phase.WAITING]
	if choosing and not game.is_opening():
		phase_name += " (planning)"
	var online_bits := ""
	if game.online and choosing:
		if game.phase == MatchGame.Phase.PLANNING and MatchGame.PLANNING_TIMER_ON:
			phase_name += " · [color=#ffd24d]%d s left[/color]" % ceili(maxf(game.planning_left, 0.0))
		online_bits = "   [color=#7fdc7f]Ready ✓[/color]" if game.ai_ready else "   [color=#9a9aa5]planning…[/color]"
	_top.text = "[b]Round %d[/b] · %s        [color=#66a6ff][b]%s[/b][/color]  HP %d   Aura %d   Reserve %d   [color=#9a9aa5](Aura given %d / %d)[/color]        [color=#ff6666][b]%s[/b][/color]  HP %d%s" % [
			game.round_number, phase_name, p.player_name, maxi(p.hp, 0), p.aura, p.reserve, p.aura_received,
			MatchRules.MAX_AURA_RECEIVED, game.ai.player_name, maxi(game.ai.hp, 0), online_bits]


func _refresh_shop() -> void:
	var p := game.player
	for child in _shop_units.get_children():
		child.queue_free()
	for slot in p.unit_offers.size():
		var data := p.unit_offers[slot]
		var info := MatchRules.offer_info(p, data)
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = data.sprite
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 34)
		var title := "%s  (tier %d)" % [data.display_name.capitalize(), data.tier]
		match info["kind"]:
			"buy":
				button.text = "%s\nBuy: %d Aura" % [title, info["aura"]]
			"upgrade":
				button.text = "%s\nUpgrade: %d Aura" % [title, info["aura"]]
			"buff":
				button.text = "%s\nBuff stats: %d Reserve" % [title, info["reserve"]]
		button.disabled = not MatchRules.can_afford(p, info)
		if info["kind"] == "upgrade":
			var owned := p.find_unit(data)
			button.pressed.connect(func(): _show_upgrade_choice(slot, owned))
		else:
			button.pressed.connect(func(): game.buy_unit(slot))
		button.mouse_entered.connect(show_unit_tip.bind(button, data))
		button.mouse_exited.connect(hide_unit_tip)
		_shop_units.add_child(button)
	for child in _shop_shards.get_children():
		child.queue_free()
	for slot in p.shard_offers.size():
		var shard := p.shard_offers[slot]
		var button := Button.new()
		button.icon = shard.get_icon()
		button.expand_icon = true
		button.custom_minimum_size = Vector2(100, 30)
		button.text = "%s\n%d" % [Shard.NAMES[shard.first_shard], MatchRules.SHARD_COST]
		button.add_theme_font_size_override("font_size", 10)
		button.tooltip_text = ItemToolbox.describe(shard)
		button.disabled = p.reserve < MatchRules.SHARD_COST
		button.pressed.connect(func(): game.buy_shard(slot))
		_shop_shards.add_child(button)
	_reroll.text = "Reroll (%d)" % p.reroll_cost
	_reroll.disabled = p.reserve < p.reroll_cost
	_lock.set_pressed_no_signal(p.shop_locked)
	_lock.text = "Locked" if p.shop_locked else "Lock"


func _refresh_bench() -> void:
	for child in _bench.get_children():
		child.queue_free()
	var bench := game.player.bench_units()
	if bench.is_empty():
		_bench.add_child(_label("(empty)", 11, Color(0.55, 0.55, 0.6)))
	for unit in bench:
		# The unit's picture with its name and path under it. Drag it to the board to place
		# it, or click it, then a cell. Items dropped on it equip it.
		var button := Button.new()
		button.text = "%s\n%s" % [unit.display_name(), RandomTeams.path_label(unit.path)]
		button.tooltip_text = unit.label()
		button.icon = unit.data.sprite
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 9)
		button.custom_minimum_size = BENCH_TILE
		if game.held.get("bench") == unit:
			button.modulate = HELD_COLOR
		button.pressed.connect(func(): game.bench_clicked(unit))
		button.set_drag_forwarding(_bench_drag.bind(unit), _can_drop_at.bind(_unit_dest.bind(unit)),
				_drop_at.bind(_unit_dest.bind(unit)))
		_bench.add_child(button)


func _item_button(item: Keepsake) -> Button:
	var button := Button.new()
	button.icon = item.get_icon()
	button.expand_icon = true
	button.custom_minimum_size = ICON
	button.tooltip_text = ItemToolbox.describe(item)
	return button


func _refresh_items() -> void:
	var p := game.player
	for child in _inventory.get_children():
		child.queue_free()
	if p.inventory.is_empty():
		_inventory.add_child(_label("(none)", 11, Color(0.55, 0.55, 0.6)))
	for i in p.inventory.size():
		var button := _item_button(p.inventory[i])
		if game.held.get("item", -1) == i:
			button.modulate = HELD_COLOR
		button.pressed.connect(func(): game.hold_item(i))
		_wire_item(button, func(): return {"from": "inventory", "index": i}, func(): return {"to": "inventory"})
		_inventory.add_child(button)
	var held_index: int = game.held.get("item", -1)
	_sell.visible = held_index >= 0
	if held_index >= 0:
		_sell.text = "Sell %s (+%d Reserve)" % [p.inventory[held_index].get_display_name(),
				MatchRules.sell_value(p.inventory[held_index])]


func _refresh_selected() -> void:
	for child in _selected_items.get_children():
		child.queue_free()
	var unit := game.selected
	if unit == null or not game.player.units.has(unit):
		_selected_label.text = "Click one of your units to see its items."
		return
	_selected_label.text = "%s's items (drag or click a Shard to take it off; keepsakes stay on):" % unit.label()
	if unit.buffs > 0:
		_selected_label.text = "%s, %d buff%s. Items (drag or click a Shard to take it off):" % [unit.label(), unit.buffs, "" if unit.buffs == 1 else "s"]
	if unit.items.is_empty():
		_selected_items.add_child(_label("(none)", 11, Color(0.55, 0.55, 0.6)))
	for i in unit.items.size():
		var button := _item_button(unit.items[i])
		button.disabled = not unit.items[i].is_shard
		button.pressed.connect(func(): game.unequip(unit, i))
		_wire_item(button, func(): return {"from": "unit", "unit": unit, "index": i}, func(): return {"to": "unit", "unit": unit})
		_selected_items.add_child(button)


func _refresh_table() -> void:
	for slot in 2:
		var item: Keepsake = game.table[slot]
		_table_slots[slot].icon = item.get_icon() if item != null else null
		_table_slots[slot].text = "" if item != null else "+"
		_table_slots[slot].tooltip_text = ItemToolbox.describe(item) if item != null else "Drag a Shard here"
	var result := game.table_preview()
	_combine.disabled = result == null
	_table_result.texture = result.get_icon() if result != null else null
	_table_result.tooltip_text = ("Makes " + ItemToolbox.describe(result)) if result != null \
			else "Drag two Shards onto the table to see what they make."
	_place_table_window.call_deferred()   # once the side panel has laid itself out


func _refresh_hint() -> void:
	if game.held.has("item"):
		_hint.text = "Holding %s: click a unit to equip it (right-click to cancel)." % \
				game.player.inventory[game.held["item"]].get_display_name()
	elif game.held.has("bench"):
		_hint.text = "Placing %s: click a cell on your half (right-click to cancel)." % game.held["bench"].label()
	else:
		_hint.text = "Drag your units to rearrange them."
