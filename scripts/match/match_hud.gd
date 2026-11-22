class_name MatchHud
extends Control
## The match screen's panels: a top bar (round and phase), health bars by the board, the planning panel on
## the right (shop with your Aura and Reserve, bench, items), the ritual table's own window, the Ascension badges, the
## log and the Ready / Fight button under the board, and pop-ups for upgrades, results and
## the end. Everything is rebuilt from the MatchGame's state by refresh().
##
## Nothing here scrolls: every panel fits on screen, and anything longer is in a hover tip
## or a pop-up. The selected unit's items are shown in the unit info panel (item_row).

## The side panel's width: with the ritual table hanging off it, the right column is as wide
## as the left one, so the centred board has the same gap on both sides.
const SIDE_WIDTH := 244.0
const ICON := Vector2(26, 26)
const HELD_COLOR := Color(1.0, 0.85, 0.3)
const FRAME_COLOR := Color(0.09, 0.09, 0.11, 0.92)
const BORDER_COLOR := Color(0.38, 0.38, 0.44)

var game: MatchGame

var _top: RichTextLabel
var _round_track: RoundTrack
var _health_bars: MatchHealthBars   # both players' health, by the board
var _money: RichTextLabel           # Aura and Reserve, in the shop's header
var _side: PanelContainer
var _shop_units: HBoxContainer
var _shop_shards: HBoxContainer
var _reroll: Button
var _shop_keepsake: HBoxContainer   # the discounted full Keepsake, from round 5
var _lock: Button
var _bench_box: PanelContainer
var _bench: HFlowContainer
var _inventory: HFlowContainer
var _sell: Button
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
var _encounter: PanelContainer
var _encounter_title: Label
var _encounter_reserve: RichTextLabel   # "You have X Reserve", for the rerolls
var _encounter_cards: HBoxContainer
var _unit_pick: PanelContainer
var _unit_pick_text: RichTextLabel
var _unit_pick_bench: HBoxContainer
var _ascension_strip: HBoxContainer
## The opponent's Ascensions: one row just under their health bar.
var _enemy_ascension_strip: HBoxContainer
var _speed_button: Button

const SPEEDS := [1.0, 2.0, 4.0]

const UNIT_TIP_WIDTH := 320.0
## Currency icons, shown in place of the words "Aura" and "Reserve".
const AURA_ICON := "res://assets/icons/aura.png"
const RESERVE_ICON := "res://assets/icons/reserve.png"
## Bottom of the top bar plus a gap: where panels under it start.
const TOP_BAR_HEIGHT := 36.0
## The log's right edge and height: it stays in the corner left of the board.
const LOG_RIGHT := 310.0
const LOG_HEIGHT := 150.0
## Screen space the unit info panel leaves free below it, for the log.
const INFO_BOTTOM_RESERVE := LOG_HEIGHT + 8.0
const BADGE := Vector2(30, 22)

## Size of the ritual table's slots and result, in pixels.
const TABLE_SLOT := 36.0
## Size of a unit's picture on the bench.
const BENCH_TILE := Vector2(50, 60)
## Size of a unit tile in the shop.
const SHOP_TILE := Vector2(74, 92)   # three across the side panel
## Where a Shard button's text starts, past its icon.
const SHARD_TEXT_LEFT := 20.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_side()
	_build_table_window()
	_build_board_drop()
	_build_bottom()
	_build_popup()
	_build_encounter()
	_build_unit_pick()
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
	_show_tip(button, describe_shop_unit(data, game.player.find_unit(data)))


## Shows an item's info in the same popup, at once (no tooltip delay), level with `button`.
## `prefix` goes above it (the ritual table's "Makes").
func show_item_tip(button: Control, item: Keepsake, prefix: String = "") -> void:
	if item == null:
		return
	var lines := ItemToolbox.describe(item).split("\n")
	var text := prefix + "[b]%s[/b]" % lines[0]
	if lines.size() > 1:
		text += "\n" + Keyphrases.format("\n".join(lines.slice(1)))
	_show_tip(button, text)


## The popup beside the shop, level with `button`, showing `bbcode`. It hides when the
## mouse leaves `button` or `button` goes away (the HUD rebuilds its buttons often).
var _tip_owner: Control

func _show_tip(button: Control, bbcode: String) -> void:
	_unit_tip_text.text = bbcode
	_unit_tip.visible = true
	_tip_owner = button
	if not button.tree_exiting.is_connected(_on_tip_owner_gone.bind(button)):
		button.tree_exiting.connect(_on_tip_owner_gone.bind(button))
	_fit_font(_unit_tip, [_unit_tip_text], [13, 12, 11, 10, 9])
	var top := clampf(button.global_position.y, 40.0, size.y - _unit_tip.size.y - 8.0)
	_unit_tip.position = Vector2(_side.global_position.x - _unit_tip.size.x - 8.0, top)


func _on_tip_owner_gone(button: Control) -> void:
	if _tip_owner == button:
		hide_unit_tip()


## Hovering `button` shows `item`'s info in the popup (see show_item_tip).
func _item_hover(button: Control, item: Keepsake, prefix: String = "") -> void:
	button.tooltip_text = ""
	button.mouse_entered.connect(func(): show_item_tip(button, item, prefix))
	button.mouse_exited.connect(hide_unit_tip)


## Steps the font of `labels` (Labels, Buttons, RichTextLabels) down through `sizes` until
## `panel` fits the screen's height (less a margin), then sizes the panel to its contents.
func _fit_font(panel: Control, labels: Array, sizes: Array) -> void:
	var room := size.y - 16.0
	for font_size in sizes:
		for label in labels:
			if label is RichTextLabel:
				label.add_theme_font_size_override("normal_font_size", font_size)
				label.add_theme_font_size_override("bold_font_size", font_size)
			else:
				label.add_theme_font_size_override("font_size", font_size)
		panel.reset_size()
		if panel.get_combined_minimum_size().y <= room:
			break
	panel.reset_size()


func hide_unit_tip() -> void:
	_unit_tip.visible = false
	_tip_owner = null


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
	if owned != null:
		lines.append("")
		lines.append("[b]You own it:[/b] buying it buffs its stats (upgrade it from its own menu).")
	return "\n".join(lines)


static func _ability_text(kind: String, ability_name: String, description: String) -> String:
	var line := "[b]%s:[/b] %s" % [kind, ability_name]
	if description != "":
		line += "\n[color=#cccccc]%s[/color]" % Keyphrases.format(description)
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


## An amount of Aura or Reserve as BBCode: the currency's icon, then the number.
static func aura_text(amount: int, icon_size: int = 13) -> String:
	return "[img=%dx%d]%s[/img] %d" % [icon_size, icon_size, AURA_ICON, amount]


static func reserve_text(amount: int, icon_size: int = 13) -> String:
	return "[img=%dx%d]%s[/img] %d" % [icon_size, icon_size, RESERVE_ICON, amount]


## Gives `button` rich text (BBCode, so it can show the currency icons) in place of its
## plain text: a RichTextLabel over it, centred, leaving `left` pixels free for the
## button's own icon (or `top` pixels, for a picture above the text). Dimmed with the
## button when it's disabled.
func _set_rich_text(button: Button, bbcode: String, font_size: int = 10, left: float = 0.0, top: float = 0.0) -> void:
	button.text = ""
	var label := button.get_node_or_null("RichText") as RichTextLabel
	if label == null:
		label = RichTextLabel.new()
		label.name = "RichText"
		label.bbcode_enabled = true
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = left
	label.offset_top = top
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.text = "[center]%s[/center]" % bbcode
	label.modulate.a = 0.45 if button.disabled else 1.0


## A header with a "(?)" that shows `tip` when hovered.
func _header_with_tip(text: String, tip: String) -> Label:
	var label := _header(text + "  (?)")
	label.tooltip_text = tip
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	return label


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
	# The round order: last round, this one, the next three. Over the side panel's column.
	_round_track = RoundTrack.new()
	_round_track.anchor_left = 1.0
	_round_track.anchor_right = 1.0
	_round_track.offset_right = -6 - maxf(SIDE_WIDTH - _round_track.custom_minimum_size.x, 0.0) / 2.0
	_round_track.offset_left = _round_track.offset_right - _round_track.custom_minimum_size.x
	_round_track.offset_top = 0
	_round_track.offset_bottom = 30
	add_child(_round_track)
	# Health bars: the opponent's above the board, yours below (with the damage animation).
	# On a layer behind the board, so the Keepsake icons of units on the top row draw over
	# the opponent's bar instead of under it.
	var bars_layer := CanvasLayer.new()
	bars_layer.layer = -1
	add_child(bars_layer)
	_health_bars = MatchHealthBars.new()
	bars_layer.add_child(_health_bars)


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
	_side.clip_contents = true   # never spills past the screen; everything is sized to fit
	# The ritual table follows the Items list when the window resizes.
	resized.connect(_place_table_window)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	_side.add_child(column)

	# Shop: unit tiles side by side (hover one for what it does), then Shards, Keepsake.
	# The header line also holds your Aura and Reserve, next to what spends them.
	var shop_head := HBoxContainer.new()
	column.add_child(shop_head)
	var shop_title := _header("Shop")
	shop_head.add_child(shop_title)
	_money = RichTextLabel.new()
	_money.bbcode_enabled = true
	_money.fit_content = true
	_money.scroll_active = false
	_money.autowrap_mode = TextServer.AUTOWRAP_OFF
	_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_money.add_theme_font_size_override("normal_font_size", 13)
	_money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_head.add_child(_money)
	_shop_units = HBoxContainer.new()
	_shop_units.add_theme_constant_override("separation", 4)
	column.add_child(_shop_units)
	_shop_shards = HBoxContainer.new()
	column.add_child(_shop_shards)
	_shop_keepsake = HBoxContainer.new()
	column.add_child(_shop_keepsake)
	var rerolls := HBoxContainer.new()
	column.add_child(rerolls)
	_reroll = Button.new()
	_reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll.pressed.connect(func(): game.reroll())
	rerolls.add_child(_reroll)
	_lock = Button.new()
	_lock.toggle_mode = true
	_lock.custom_minimum_size = Vector2(64, 0)
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
	bench_column.add_child(_header_with_tip("Bench", "Drag units between here and the board, or click one, then a cell."))
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
	items_column.add_child(_header_with_tip("Items", "Drag items between here, your units and the ritual table, or click one to hold it.\nRight-click a Shard (anywhere) to send it to the ritual table; left-click a Shard on a unit or the table to bring it back here.\nDrag a shop item or the ritual's result out to buy or make it.\nClick one of your units to see its items."))
	_inventory = HFlowContainer.new()
	items_column.add_child(_inventory)
	_sell = Button.new()
	_sell.pressed.connect(func(): game.sell_held())
	items_column.add_child(_sell)


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
		var button := RichTooltipButton.new()
		button.custom_minimum_size = Vector2(TABLE_SLOT, TABLE_SLOT)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.expand_icon = true
		button.pressed.connect(func(): game.table_clicked(slot))
		_wire_item(button, func(): return {"from": "table", "slot": slot}, func(): return {"to": "table", "slot": slot})
		button.mouse_entered.connect(func(): show_item_tip(button, game.table[slot]))
		button.mouse_exited.connect(hide_unit_tip)
		column.add_child(button)
		_table_slots.append(button)
	column.add_child(_centered_label("="))
	_table_result = RichTooltipRect.new()
	_table_result.custom_minimum_size = Vector2(TABLE_SLOT, TABLE_SLOT)
	_table_result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_table_result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_table_result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_table_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_wire_item(_table_result, func(): return {"from": "table_result"}, Callable())   # drag it out to combine
	_table_result.mouse_entered.connect(func(): show_item_tip(_table_result, game.table_preview(), "Makes "))
	_table_result.mouse_exited.connect(hide_unit_tip)
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
	_hint.offset_left = -225   # centred over the board
	_hint.offset_right = 225
	_hint.offset_top = 36
	_hint.offset_bottom = 56
	add_child(_hint)

	_log = _label("", 11, Color(0.8, 0.8, 0.84))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.anchor_top = 1.0
	_log.anchor_bottom = 1.0
	_log.offset_left = 8
	_log.offset_right = LOG_RIGHT
	_log.offset_top = -LOG_HEIGHT
	_log.offset_bottom = -6
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log)

	_ready_button = Button.new()
	_ready_button.add_theme_font_size_override("font_size", 18)
	_ready_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ready_button.offset_left = -75   # centred under the board
	_ready_button.offset_right = 75
	_ready_button.offset_top = -50
	_ready_button.offset_bottom = -10
	_ready_button.pressed.connect(func(): game.press_ready())
	add_child(_ready_button)

	# Ascensions: a row of badges on the far side of each health bar from the board (yours
	# under yours, the opponent's above theirs), the same distance from each. Placed by
	# _layout_center.
	_ascension_strip = _ascension_row()
	_enemy_ascension_strip = _ascension_row()


func _ascension_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(row)
	return row


## Gap between a health bar's edge and its Ascension row.
const ASCENSION_GAP := 6.0


## Places what sits around the board, which is centred across the screen (its centre
## moves when the window changes shape).
func _layout_center() -> void:
	var center_x := MatchGame.board_screen_center.x
	var bar_half := MatchHealthBars.BAR_SIZE.y / 2.0 + 2.0   # with its frame
	for row in [_ascension_strip, _enemy_ascension_strip]:
		row.offset_left = center_x - 230
		row.offset_right = center_x + 230
	_ascension_strip.offset_top = MatchHealthBars.BOTTOM_Y + bar_half + ASCENSION_GAP
	_ascension_strip.offset_bottom = _ascension_strip.offset_top + BADGE.y
	_enemy_ascension_strip.offset_bottom = MatchHealthBars.TOP_Y - bar_half - ASCENSION_GAP
	_enemy_ascension_strip.offset_top = _enemy_ascension_strip.offset_bottom - BADGE.y
	_health_bars.queue_redraw()


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


## The Encounter pick: a title and one card per Ascension on offer, over the board.
func _build_encounter() -> void:
	_encounter = PanelContainer.new()
	_encounter.add_theme_stylebox_override("panel", _frame(14))
	_encounter.visible = false
	add_child(_encounter)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_encounter.add_child(column)
	_encounter_title = _label("", 18)
	_encounter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_encounter_title)
	var hint := _label("Choose one. It lasts for the rest of the match.", 11, Color(0.7, 0.7, 0.76))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF   # wrapping at no width would make the panel huge
	column.add_child(hint)
	# Your Reserve, for the rerolls (the shop, where it usually shows, is hidden here).
	_encounter_reserve = RichTextLabel.new()
	_encounter_reserve.bbcode_enabled = true
	_encounter_reserve.fit_content = true
	_encounter_reserve.scroll_active = false
	_encounter_reserve.autowrap_mode = TextServer.AUTOWRAP_OFF
	_encounter_reserve.add_theme_font_size_override("normal_font_size", 13)
	_encounter_reserve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_encounter_reserve)
	_encounter_cards = HBoxContainer.new()
	_encounter_cards.add_theme_constant_override("separation", 10)
	column.add_child(_encounter_cards)


const ENCOUNTER_CARD := Vector2(190, 130)

## Shows the Encounter pick for the player's ascension_offers, or hides it when there are none.
func show_encounter(title: String) -> void:
	for child in _encounter_cards.get_children():
		_encounter_cards.remove_child(child)   # now, so the last Encounter's cards don't count toward the size
		child.queue_free()
	var offers := game.player.ascension_offers
	_encounter.visible = not offers.is_empty() and not MatchGame.spectating
	if not _encounter.visible:
		return
	_encounter_title.text = title
	_encounter_reserve.text = "[center]You have %s[/center]" % reserve_text(game.player.reserve, 13)
	var can_reroll := game.can_reroll_ascensions()
	for slot in offers.size():
		var ascension := offers[slot]
		var card := Button.new()
		card.custom_minimum_size = ENCOUNTER_CARD
		card.pressed.connect(func(): game.choose_ascension(slot))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.offset_left = 8
		text.offset_top = 8
		text.offset_right = -8
		text.offset_bottom = -8
		text.add_theme_font_size_override("normal_font_size", 12)
		text.add_theme_font_size_override("bold_font_size", 14)
		var for_text := ""
		if ascension.is_chosen():
			for_text = "  [color=#ffd24d]Pick a unit[/color]"
		elif ascension.favors_beams:
			for_text = "  [color=#c8b46e]For Beams[/color]"
		elif not ascension.affected_units.is_empty():
			for_text = "  [color=#c8b46e]For %s[/color]" % ascension.affected_names()
		var for_units := "[center][color=#9a9aa5]Tier %s[/color]%s[/center]" % [ascension.tier_text(), for_text]
		text.text = "[center][b]%s[/b][/center]%s\n%s" % [ascension.get_display_name(), for_units, Keyphrases.format(ascension.description)]
		card.add_child(text)
		# The card, with its own reroll button under it (all share one rising price).
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		stack.add_child(card)
		if not game._dev_encounter:
			var reroll := Button.new()
			reroll.custom_minimum_size = Vector2(0, 28)
			reroll.focus_mode = Control.FOCUS_NONE
			reroll.tooltip_text = "Swap this Ascension for a different one. Every reroll raises the price of all of them by 1; it resets at the next Encounter."
			reroll.disabled = not can_reroll
			reroll.pressed.connect(func(): game.reroll_ascension(slot))
			_set_rich_text(reroll, "Reroll   " + reserve_text(game.player.ascension_reroll_cost, 13), 13)
			stack.add_child(reroll)
		_encounter_cards.add_child(stack)
	_place_encounter.call_deferred()


## Size of the faction emblem peeking over a faction Ascension's badge, in pixels, and how
## far above the badge's top edge its centre sits.
const EMBLEM_SIZE := 10.0
const EMBLEM_RISE := 1.0


## A faction's emblem (the round track's: Sword Court's pierced crown, Obelisk's eye), in
## the faction's colour.
class FactionEmblem extends Control:
	var faction := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var color: Color = RoundTrack.FACTION_COLORS.get(faction, RoundTrack.NEUTRAL_COLOR)
		RoundTrack.draw_icon(self, RoundTrack.Kind.FACTION, faction, size / 2.0, size.x, color)


## Centres the Encounter panel on the board once its cards are laid out.
func _place_encounter() -> void:
	_encounter.reset_size()
	_encounter.position = MatchGame.board_screen_center - _encounter.size / 2.0


func hide_encounter() -> void:
	_encounter.visible = false


## The banner while picking the unit for a chosen-unit Ascension: what it is, any eligible
## bench units to click, and Back.
func _build_unit_pick() -> void:
	_unit_pick = PanelContainer.new()
	_unit_pick.add_theme_stylebox_override("panel", _frame(10))
	_unit_pick.visible = false
	add_child(_unit_pick)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_unit_pick.add_child(column)
	_unit_pick_text = RichTextLabel.new()
	_unit_pick_text.bbcode_enabled = true
	_unit_pick_text.fit_content = true
	_unit_pick_text.scroll_active = false
	_unit_pick_text.custom_minimum_size = Vector2(420, 0)
	_unit_pick_text.add_theme_font_size_override("normal_font_size", 13)
	_unit_pick_text.add_theme_font_size_override("bold_font_size", 13)
	column.add_child(_unit_pick_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	_unit_pick_bench = HBoxContainer.new()
	_unit_pick_bench.add_theme_constant_override("separation", 4)
	_unit_pick_bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_unit_pick_bench)
	var back := Button.new()
	back.text = "Back"
	back.tooltip_text = "Choose a different Ascension (or right-click)."
	back.size_flags_vertical = Control.SIZE_SHRINK_END
	back.pressed.connect(func(): game.cancel_unit_pick())
	row.add_child(back)


func show_unit_pick(ascension: Ascension, bench: Array) -> void:
	var lines := PackedStringArray(["[b]Choose a unit for %s[/b]: click it on the board." % ascension.get_display_name()])
	lines.append(Keyphrases.format(ascension.description))
	if not bench.is_empty():
		lines.append("[color=#9a9aa5]Or one on your bench:[/color]")
	_unit_pick_text.text = "\n".join(lines)
	for child in _unit_pick_bench.get_children():
		_unit_pick_bench.remove_child(child)
		child.queue_free()
	for unit in bench:
		var tile := Button.new()
		tile.text = "%s\n%s" % [unit.display_name(), RandomTeams.path_label(unit.path)]
		tile.icon = unit.data.sprite
		tile.expand_icon = true
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.clip_text = true
		tile.add_theme_font_size_override("font_size", 9)
		tile.custom_minimum_size = BENCH_TILE
		tile.pressed.connect(func(): game.pick_unit(unit))
		_unit_pick_bench.add_child(tile)
	_unit_pick.visible = true
	_place_unit_pick.call_deferred()


func _place_unit_pick() -> void:
	_unit_pick.reset_size()
	_unit_pick.position = Vector2(MatchGame.board_screen_center.x - _unit_pick.size.x / 2.0, TOP_BAR_HEIGHT + 4.0)


func hide_unit_pick() -> void:
	_unit_pick.visible = false


## The Ascension rows: a badge per Ascension under your health bar; the opponent's (as
## their last army had them) above theirs. Hover a badge for its name, tier
## and description.
func _refresh_ascensions() -> void:
	_layout_center()
	for strip in [_ascension_strip, _enemy_ascension_strip]:
		for child in strip.get_children():
			strip.remove_child(child)
			child.queue_free()
	var mine := game.player.ascensions
	for i in mine.size():
		_ascension_strip.add_child(_ascension_badge(mine[i], i, MatchRules.holder_of(game.player.units, mine[i])))
	var theirs := game.ai.last_fielded_ascensions
	for i in theirs.size():
		_enemy_ascension_strip.add_child(_ascension_badge(theirs[i], i, MatchRules.holder_of(game.ai.last_fielded, theirs[i])))
	_ascension_strip.visible = _ascension_strip.get_child_count() > 0
	_enemy_ascension_strip.visible = _enemy_ascension_strip.get_child_count() > 0


## The tier an Ascension was picked at. A player takes one per Encounter, in order, so the
## `index`-th in their list came from Encounter index + 1; kept within the tiers the
## Ascension can be offered at (a unit Ascension spans two).
static func _picked_tier(ascension: Ascension, index: int) -> int:
	var tiers := ascension.encounter_tiers()
	return clampi(MatchRules.encounter_tier(index + 1), int(tiers.min()), int(tiers.max()))


## A small square showing the Ascension's tier, tinted by its main stat; its tooltip has
## the rest.
func _ascension_badge(ascension: Ascension, index: int, holder: ArmyUnit = null) -> Button:
	var tier := _picked_tier(ascension, index)
	var badge := RichTooltipButton.new()
	badge.bbcode_tooltip = true
	badge.focus_mode = Control.FOCUS_NONE
	badge.custom_minimum_size = BADGE
	badge.text = Ascension.NUMERALS[clampi(tier, 0, 4)]
	badge.add_theme_font_size_override("font_size", 11)
	var style := StyleBoxFlat.new()
	style.bg_color = _ascension_tint(ascension).darkened(0.35)
	style.border_color = Color(1, 1, 1, 0.5) if ascension.family != null or ascension.empowers != null else Color(1, 1, 1, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	for state in ["normal", "hover", "pressed"]:
		badge.add_theme_stylebox_override(state, style)
	var lines := PackedStringArray(["[b]%s[/b]   [color=#9a9aa5]Tier %d[/color]" % [ascension.get_display_name(), tier]])
	if holder != null:
		lines.append("[color=#ffd24d]On %s[/color]" % holder.label().strip_edges())
	elif ascension.favors_beams:
		lines.append("[color=#c8b46e]For Beams[/color]")
	elif not ascension.affected_units.is_empty():
		lines.append("[color=#c8b46e]For %s[/color]" % ascension.affected_names())
	lines.append(Keyphrases.format(ascension.description))
	badge.tooltip_text = "\n".join(lines)
	# A faction's Ascension: its emblem peeking over the badge's top edge.
	var faction := ascension.faction_name()
	if faction != "":
		var emblem := FactionEmblem.new()
		emblem.faction = faction
		emblem.size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
		emblem.position = Vector2((BADGE.x - EMBLEM_SIZE) / 2.0, -EMBLEM_SIZE / 2.0 - EMBLEM_RISE)
		badge.add_child(emblem)
	return badge


## The colour of the stat an Ascension gives most of (grey if it gives none).
static func _ascension_tint(ascension: Ascension) -> Color:
	var best := 0.0
	var tint := Color(0.5, 0.5, 0.55)
	var kinds := {Stats.Stat.MIGHT: Shard.Kind.MIGHT, Stats.Stat.MIGHT_WARD: Shard.Kind.MIGHT_WARD,
			Stats.Stat.CELERITY: Shard.Kind.CELERITY, Stats.Stat.CELERITY_WARD: Shard.Kind.CELERITY_WARD,
			Stats.Stat.INSIGHT: Shard.Kind.INSIGHT, Stats.Stat.INSIGHT_WARD: Shard.Kind.INSIGHT_WARD}
	var bonuses := ascension.get_stat_bonuses()
	for stat in kinds:
		if bonuses.get(stat, 0.0) > best:
			best = bonuses[stat]
			tint = Keyphrases.color_of(kinds[stat])
	if ascension.health / 10.0 > best:   # Health comes in bigger numbers
		tint = Keyphrases.color_of(Shard.Kind.HEALTH)
	return tint


## Shows the pop-up with `text` and one button per [label, callable].
func _show_popup(text: String, buttons: Array) -> void:
	_popup_text.text = text
	for child in _popup_buttons.get_children():
		_popup_buttons.remove_child(child)   # now, so the old buttons don't count toward the size
		child.queue_free()
	var labels: Array = [_popup_text]
	for entry in buttons:
		var button := Button.new()
		button.text = entry[0]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(entry[1])
		button.disabled = entry.size() > 2 and entry[2]
		_popup_buttons.add_child(button)
		labels.append(button)
	_popup.visible = true
	_fit_font(_popup, labels, [14, 13, 12, 11, 10, 9])
	_popup.position = (MatchGame.board_screen_center - _popup.size / 2.0).clamp(
			Vector2(8, 8), size - _popup.size - Vector2(8, 8))


func hide_result() -> void:
	_popup.visible = false


## Keeps the health bars at these values (true = yours) until play_damage moves them.
## The round of the next combat (combats are on even rounds): this one while planning a
## combat round, otherwise the next even round after it.
func _next_combat_round() -> int:
	var r := game.round_number
	if r % 2 == 1:
		return r + 1
	return r if game.phase == MatchGame.Phase.PLANNING else r + 2


func hold_health(hp: Dictionary) -> void:
	_health_bars.hold(hp)


## The post-fight damage animation (see MatchHealthBars.play_damage). Await it.
func play_damage(hits: Array) -> void:
	await _health_bars.play_damage(hits)


func show_result(text: String) -> void:
	_show_popup(text, [["Continue", func(): game.continue_after_result()]])


func show_game_over(text: String) -> void:
	_show_popup(text, [["New match", func(): game.new_match()],
			["Main menu", func(): game.return_to_menu()]])


## `unit`'s upgrade choices, as two small
## cards beside the unit info panel. Click one to buy it; click anywhere else (or the
## Upgrade button again) to close. Planning only.
func show_upgrade_menu(unit: ArmyUnit) -> void:
	if unit.is_maxed() or game.phase != MatchGame.Phase.PLANNING or MatchGame.spectating:
		return
	if _upgrade_menu == null:
		_build_upgrade_menu()
	if _upgrade_menu.visible and _upgrade_menu_unit == unit:
		hide_upgrade_menu()   # the button again: close
		return
	_upgrade_menu_unit = unit
	var short := not MatchRules.can_buy_upgrade(game.player, unit)
	_upgrade_short.visible = short
	_upgrade_short.text = "Needs %d Aura (you have %d)" % [MatchRules.upgrade_cost(unit), game.player.aura]
	for child in _upgrade_cards.get_children():
		_upgrade_cards.remove_child(child)
		child.queue_free()
	for choice in MatchRules.upgrade_choices(unit):
		_upgrade_cards.add_child(_upgrade_card(unit, choice, short))
	_upgrade_menu.visible = true
	_place_upgrade_menu()
	_place_upgrade_menu.call_deferred()   # again once the cards' text has laid out


## Beside the unit info panel, level with the Upgrade button, shrunk to fit its cards.
func _place_upgrade_menu() -> void:
	if _upgrade_menu == null or not _upgrade_menu.visible:
		return
	_upgrade_menu.reset_size()
	var panel := game.unit_info.get_global_rect()
	var top := game.unit_info.upgrade_row.get_global_rect().position.y
	_upgrade_menu.position = Vector2(panel.end.x + 6, top).clamp(Vector2(8, 8), size - _upgrade_menu.size - Vector2(8, 8))


## One path's card: its letter and name, then what it does. Highlights on hover; a click
## buys it (unless you can't afford it).
func _upgrade_card(unit: ArmyUnit, choice: Dictionary, short: bool) -> PanelContainer:
	var upgrade: Upgrade = choice["upgrade"]
	var path := unit.path.duplicate()
	path.append(choice["index"])
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(UPGRADE_CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15)
	style.border_color = UPGRADE_CYAN if not short else UPGRADE_CYAN.darkened(0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(7)
	card.add_theme_stylebox_override("panel", style)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.custom_minimum_size = Vector2(UPGRADE_CARD_WIDTH - 14, 0)   # wraps at this width, not at 0
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("normal_font_size", 11)
	text.add_theme_font_size_override("bold_font_size", 12)
	var label := RandomTeams.path_label(path)
	var name_part := " " + upgrade.upgrade_name if upgrade.upgrade_name not in ["", "Upgrade"] else ""
	var body := Keyphrases.format(upgrade.description) if upgrade.description != "" else describe_upgrade(upgrade)
	text.text = "[b][color=#%s]%s[/color]%s[/b]
%s" % [UPGRADE_CYAN.lightened(0.3).to_html(false), label, name_part, body]
	if short:
		text.modulate.a = 0.55
	card.add_child(text)
	if not short:
		card.mouse_entered.connect(func(): style.bg_color = Color(0.13, 0.25, 0.29))
		card.mouse_exited.connect(func(): style.bg_color = Color(0.12, 0.12, 0.15))
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_pick_aura_upgrade(unit, choice["index"]))
	return card


const UPGRADE_CARD_WIDTH := 175.0
var _upgrade_menu: PanelContainer
var _upgrade_menu_unit: ArmyUnit   # whose choices are showing
var _upgrade_short: Label          # "Needs X Aura", when you can't afford it
var _upgrade_cards: HBoxContainer

## The upgrade cards' small frame. Built on first use.
func _build_upgrade_menu() -> void:
	_upgrade_menu = PanelContainer.new()
	var style := _frame(5)
	style.border_color = UPGRADE_CYAN.darkened(0.3)
	_upgrade_menu.add_theme_stylebox_override("panel", style)
	_upgrade_menu.visible = false
	add_child(_upgrade_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_upgrade_menu.add_child(column)
	_upgrade_short = _label("", 11, Color(1.0, 0.5, 0.5))
	column.add_child(_upgrade_short)
	_upgrade_cards = HBoxContainer.new()
	_upgrade_cards.add_theme_constant_override("separation", 5)
	column.add_child(_upgrade_cards)


func hide_upgrade_menu() -> void:
	if _upgrade_menu != null:
		_upgrade_menu.visible = false


## Closes the upgrade cards on a click anywhere outside them (the Upgrade button toggles
## them itself). Doesn't take the click: whatever was under it still gets it.
func _close_upgrade_menu_on_outside_click(event: InputEvent) -> void:
	if _upgrade_menu == null or not _upgrade_menu.visible:
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if _upgrade_menu.get_global_rect().has_point(click.position):
		return
	if game.unit_info.upgrade_row.visible and game.unit_info.upgrade_row.get_global_rect().has_point(click.position):
		return
	hide_upgrade_menu()


func _pick_aura_upgrade(unit: ArmyUnit, choice: int) -> void:
	hide_upgrade_menu()
	game.buy_upgrade(unit, choice)


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


func is_over_bench(screen_point: Vector2) -> bool:
	return _side.visible and _bench_box.get_global_rect().has_point(screen_point)


# ---------- Filling in ----------

func refresh() -> void:
	if game == null:
		return
	hide_unit_tip()   # the shop buttons are about to be rebuilt
	var planning := game.phase == MatchGame.Phase.PLANNING and not MatchGame.spectating
	_side.visible = planning
	if not planning:
		hide_upgrade_menu()   # upgrades are bought in planning only
	_table_window.visible = planning
	_hint.visible = planning
	_spectate_bar.visible = MatchGame.spectating
	_refresh_top()
	_refresh_ascensions()
	refresh_selected()
	_log.text = "\n".join(game.log_lines)
	var waiting := game.phase == MatchGame.Phase.WAITING
	_ready_button.visible = planning or waiting
	# You can ready up any time; the round starts once both players are. While waiting, the
	# button un-readies you (back to planning) until then.
	var go_text := "Done" if game.is_opening() else "Fight!"
	if waiting and game._unready_pending:
		_ready_button.disabled = true
		_ready_button.text = "Un-readying..."
	elif waiting:
		_ready_button.disabled = false
		_ready_button.text = "Un-ready (waiting for opponent)"
	else:
		_ready_button.disabled = false
		_ready_button.text = go_text if game.ai_ready else "Ready"
	if not planning:
		return
	_refresh_shop()
	_refresh_bench()
	_refresh_items()
	_refresh_table()
	_refresh_hint()


## Just the top bar, e.g. for the planning countdown.
func refresh_top() -> void:
	if game != null:
		_refresh_top()


func _refresh_top() -> void:
	var p := game.player
	_round_track.show_round(game.round_number, p.faction)
	var phase_name := "Opening Shop" if game.is_opening() else "Player Combat"
	if game.phase == MatchGame.Phase.ENCOUNTER:
		phase_name = "Encounter"
	var choosing := game.phase in [MatchGame.Phase.PLANNING, MatchGame.Phase.WAITING]
	if choosing and not game.is_opening():
		phase_name += " (planning)"
	var online_bits := ""
	if game.online and choosing:
		if game.phase == MatchGame.Phase.PLANNING and MatchGame.PLANNING_TIMER_ON:
			phase_name += " · [color=#ffd24d]%d s left[/color]" % ceili(maxf(game.planning_left, 0.0))
		online_bits = "   [color=#7fdc7f]Ready ✓[/color]" if game.ai_ready else "   [color=#9a9aa5]planning…[/color]"
	# Health is on the bars by the board, money in the shop.
	_top.text = "[b]Round %d[/b] · %s%s" % [game.round_number, phase_name, online_bits]
	_money.text = "%s  %s  [font_size=10][color=#9a9aa5](%s given / %d)[/color][/font_size]" % [aura_text(p.aura, 13), reserve_text(p.reserve, 13),
			aura_text(p.aura_received, 10), MatchRules.max_aura_received()]
	_health_bars.show_players(p, game.ai, _next_combat_round())


func _refresh_shop() -> void:
	var p := game.player
	for child in _shop_units.get_children():
		child.queue_free()
	for slot in p.unit_offers.size():
		var data := p.unit_offers[slot]
		var info := MatchRules.offer_info(p, data)
		# A tile: the unit's picture, its name and tier, and what clicking it costs.
		var button := Button.new()
		button.clip_text = true
		button.custom_minimum_size = SHOP_TILE
		var picture := TextureRect.new()
		picture.texture = data.sprite
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_top = 4
		picture.offset_bottom = -34
		button.add_child(picture)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 10)
		var title := "%s (T%d)" % [data.display_name.capitalize(), data.tier]
		var cost := ""
		match info["kind"]:
			"buy":
				cost = "Buy " + aura_text(info["aura"])
			"buff":
				cost = "Buff " + reserve_text(info["reserve"])
		button.disabled = not MatchRules.can_afford(p, info)
		_set_rich_text(button, "%s\n%s" % [title, cost], 10, 0.0, SHOP_TILE.y - 34.0)
		picture.modulate.a = 0.45 if button.disabled else 1.0
		button.pressed.connect(func(): game.buy_unit(slot))
		button.mouse_entered.connect(show_unit_tip.bind(button, data))
		button.mouse_exited.connect(hide_unit_tip)
		_shop_units.add_child(button)
	for child in _shop_shards.get_children():
		child.queue_free()
	for slot in p.shard_offers.size():
		var shard := p.shard_offers[slot]
		var button := RichTooltipButton.new()
		button.icon = shard.get_icon()
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.disabled = p.reserve < MatchRules.SHARD_COST
		# The name steps down a size or two if it wouldn't fit beside the icon (a centred
		# line that's too wide spills out of the button and gets cut off at both ends).
		var shard_name: String = Shard.NAMES[shard.first_shard]
		var name_size := 9
		var room := (SIDE_WIDTH - 12.0) / maxf(p.shard_offers.size(), 1.0) - SHARD_TEXT_LEFT - 6.0
		while name_size > 7 and get_theme_default_font().get_string_size(shard_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > room:
			name_size -= 1
		_set_rich_text(button, "[font_size=%d]%s[/font_size]\n%s" % [name_size, shard_name, reserve_text(MatchRules.SHARD_COST, 10)], 9, SHARD_TEXT_LEFT)
		button.add_theme_font_size_override("font_size", 9)
		button.add_theme_constant_override("icon_max_width", 14)
		_item_hover(button, shard)
		button.pressed.connect(func(): game.buy_shard(slot))
		_on_right_click(button, func(): game.shard_to_table({"from": "shop_shard", "slot": slot}))
		_wire_item(button, func(): return {"from": "shop_shard", "slot": slot}, Callable())
		_shop_shards.add_child(button)
	for child in _shop_keepsake.get_children():
		child.queue_free()
	if p.keepsake_offer != null:
		var keepsake := p.keepsake_offer
		var button := RichTooltipButton.new()
		button.icon = keepsake.get_icon()
		button.expand_icon = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 30)
		button.disabled = p.reserve < MatchRules.KEEPSAKE_COST
		_set_rich_text(button, "%s   %s [color=#9a9aa5](was %d, once a round)[/color]" % [keepsake.get_display_name(),
				reserve_text(MatchRules.KEEPSAKE_COST, 11), MatchRules.SHARD_COST * 2], 10, 28.0)
		button.add_theme_font_size_override("font_size", 10)
		_item_hover(button, keepsake)
		button.pressed.connect(func(): game.buy_keepsake())
		_wire_item(button, func(): return {"from": "shop_keepsake"}, Callable())
		_shop_keepsake.add_child(button)
	_reroll.disabled = p.reserve < p.reroll_cost
	_set_rich_text(_reroll, "Reroll   " + reserve_text(p.reroll_cost, 14), 15)
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
		if not unit.is_maxed():
			button.tooltip_text += "\nRight-click to upgrade (%d Aura)." % MatchRules.upgrade_cost(unit)
			button.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					show_upgrade_menu(unit))
		button.set_drag_forwarding(_bench_drag.bind(unit), _can_drop_at.bind(_unit_dest.bind(unit)),
				_drop_at.bind(_unit_dest.bind(unit)))
		button.set_meta("army_unit", unit)   # so flash_refusal can find it
		if game.phase == MatchGame.Phase.PLANNING and MatchRules.upgrade_affordable(game.player, unit):
			_mark_upgrade_ready(button)
		_bench.add_child(button)


# ---------- The countdown before a fight ----------

var _intro: Control = null

## Over the board before a fight: a big countdown (3, 2, 1, Fight!) and, when either player
## picked an Ascension at the Encounter just before, a panel with each side's picks.
func show_combat_intro(left_name: String, left_picks: Array[Ascension], right_name: String,
		right_picks: Array[Ascension], seconds: float) -> void:
	hide_combat_intro()
	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intro)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	_intro.add_child(column)
	if not left_picks.is_empty() or not right_picks.is_empty():
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _frame(12))
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inside := VBoxContainer.new()
		inside.add_theme_constant_override("separation", 6)
		var title := _label("Ascensions picked", 16, Color(0.85, 0.85, 0.9))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inside.add_child(title)
		var sides := HBoxContainer.new()
		sides.add_theme_constant_override("separation", 24)
		var mine := BattleUnit.team_color(game.my_team)
		var theirs := BattleUnit.team_color(3 - game.my_team)
		sides.add_child(_intro_side(left_name, left_picks, mine))
		sides.add_child(_intro_side(right_name, right_picks, theirs))
		inside.add_child(sides)
		panel.add_child(inside)
		column.add_child(panel)
	var count := Label.new()
	count.add_theme_font_size_override("font_size", 72)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	count.add_theme_constant_override("outline_size", 10)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(count)
	# Centred on the board once it has its size.
	column.reset_size()
	column.position = MatchGame.board_screen_center - column.get_combined_minimum_size() / 2.0
	# 3, 2, 1 one second apart (scaled to `seconds`), each popping in and fading.
	var steps := int(round(seconds))
	var step_time := seconds / maxi(steps, 1)
	var tween := count.create_tween()
	for i in steps:
		var n := steps - i
		tween.tween_callback(func():
			count.text = str(n)
			count.pivot_offset = count.size / 2.0
			count.scale = Vector2.ONE * 1.4
			count.modulate.a = 1.0)
		tween.tween_property(count, "scale", Vector2.ONE, step_time * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(count, "modulate:a", 0.35, step_time * 0.65)


## One side's column in the countdown panel: the player's name in their colour, then each
## Ascension they picked with its description (or "No pick" if they picked none).
func _intro_side(player_name: String, picks: Array[Ascension], color: Color) -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(230, 0)
	side.add_theme_constant_override("separation", 3)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(_label(player_name, 15, color))
	if picks.is_empty():
		side.add_child(_label("No pick", 12, Color(0.55, 0.55, 0.6)))
	for ascension in picks:
		var faction := ascension.faction_name()
		var tint: Color = RoundTrack.FACTION_COLORS.get(faction, RoundTrack.NEUTRAL_COLOR)
		side.add_child(_label(ascension.get_display_name(), 14, tint))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.custom_minimum_size = Vector2(230, 0)
		text.add_theme_font_size_override("normal_font_size", 11)
		text.text = Keyphrases.format(ascension.description)
		side.add_child(text)
	return side


## Takes the countdown away (the fight is starting).
func hide_combat_intro() -> void:
	if is_instance_valid(_intro):
		_intro.queue_free()
	_intro = null


## A benched unit you can afford to upgrade: the bench's version of the board's cyan glow
## and arrow, cyan text and a cyan up-arrow in the tile's corner.
func _mark_upgrade_ready(button: Button) -> void:
	button.add_theme_color_override("font_color", KeepsakeVfx.UPGRADE_READY_COLOR)
	var arrow := Label.new()
	arrow.text = "▲"
	arrow.add_theme_color_override("font_color", KeepsakeVfx.UPGRADE_READY_COLOR)
	arrow.add_theme_color_override("font_outline_color", Color(0.02, 0.12, 0.18))
	arrow.add_theme_constant_override("outline_size", 3)
	arrow.add_theme_font_size_override("font_size", 12)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.anchor_left = 1.0
	arrow.anchor_right = 1.0
	arrow.offset_left = -14
	arrow.offset_top = 1
	button.add_child(arrow)
	button.tooltip_text += "
You can afford an upgrade."


## A benched unit refusing an item (a Keepsake it already has a copy of): its tile flashes
## red and wobbles, the bench's version of the board's red outline and shake.
func flash_refusal(unit: ArmyUnit) -> void:
	for child in _bench.get_children():
		if not child.has_meta("army_unit") or child.get_meta("army_unit") != unit or child.is_queued_for_deletion():
			continue
		var tile := child as Control
		tile.pivot_offset = tile.size / 2.0
		tile.modulate = KeepsakeVfx.REFUSE_COLOR
		var tween := tile.create_tween()
		for angle in [0.12, -0.12, 0.08, -0.08, 0.0]:   # radians: a quick "no" wobble
			tween.tween_property(tile, "rotation", angle, KeepsakeVfx.REFUSE_SHAKE_STEP)
		tween.parallel().tween_property(tile, "modulate", Color.WHITE, KeepsakeVfx.REFUSE_TIME)
		return


## Closes the upgrade menu on a click outside it.
func _input(event: InputEvent) -> void:
	_close_upgrade_menu_on_outside_click(event)


## Runs `action` when `control` is right-clicked (Shards: off to the ritual table).
func _on_right_click(control: Control, action: Callable) -> void:
	control.gui_input.connect(func(event: InputEvent):
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			action.call()
			control.accept_event())


func _item_button(item: Keepsake) -> Button:
	var button := RichTooltipButton.new()
	button.icon = item.get_icon()
	button.expand_icon = true
	button.custom_minimum_size = ICON
	_item_hover(button, item)
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
		var item: Keepsake = p.inventory[i]
		button.pressed.connect(func(): game.hold_item(i))
		_on_right_click(button, func(): game.shard_to_table({"from": "inventory", "index": i}))
		_wire_item(button, func(): return {"from": "inventory", "index": i}, func(): return {"to": "inventory"})
		_inventory.add_child(button)
	var held_index: int = game.held.get("item", -1)
	_sell.visible = held_index >= 0
	if held_index >= 0:
		_sell.custom_minimum_size.y = 28
		_set_rich_text(_sell, "Sell %s (+%s)" % [p.inventory[held_index].get_display_name(),
				reserve_text(MatchRules.sell_value(p.inventory[held_index]))], 12)


## The items of the unit shown in the unit info panel, as buttons in its item row: drag or
## click a Shard to take it off (Keepsakes stay on), or drop items on the row to equip.
## Only for your own units while planning.
const UPGRADE_CYAN := Color(0.17, 0.71, 0.81)
const UPGRADE_INK := Color(0.02, 0.16, 0.2)   # text on the cyan
const UPGRADE_BUTTON_HEIGHT := 30.0

## Aura upgrade system: the solid cyan "UPGRADE (Aura) cost" button at the top of the unit
## info panel, for one of your units in planning that can still upgrade. Opens the two
## small upgrade cards beside the panel. Greyed (but still opens them, to read) when you
## can't afford it. Hidden otherwise.
func _refresh_upgrade_button(unit: ArmyUnit) -> void:
	var slot := game.unit_info.upgrade_row
	if _upgrade_menu != null and _upgrade_menu_unit != unit:
		hide_upgrade_menu()   # another unit (or none) is shown now
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	slot.visible = unit != null and not unit.is_maxed()
	if not slot.visible:
		return
	var cost := MatchRules.upgrade_cost(unit)
	var affordable := MatchRules.can_buy_upgrade(game.player, unit)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, UPGRADE_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "Choose this unit's next upgrade." if affordable \
			else "Choose this unit's next upgrade. You have %d Aura." % game.player.aura
	var base := UPGRADE_CYAN if affordable else UPGRADE_CYAN.lerp(Color(0.35, 0.37, 0.4), 0.7)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {"normal": base, "hover": base.lightened(0.15), "pressed": base.darkened(0.15), "focus": base}[state]
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(show_upgrade_menu.bind(unit))
	slot.add_child(button)
	_set_rich_text(button, "[b][color=#%s]UPGRADE[/color][/b]  %s" % [UPGRADE_INK.to_html(false),
			aura_text(cost, 14).replace("[/img] ", "[/img] [color=#%s]" % UPGRADE_INK.to_html(false)) + "[/color]"], 14)


func refresh_selected() -> void:
	var row := game.unit_info.item_row
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var shown := game.unit_info.get_unit()
	var unit: ArmyUnit = null
	if shown != null and shown.team == MatchGame.PLAYER_TEAM and game.phase == MatchGame.Phase.PLANNING and not MatchGame.spectating:
		var index: int = shown.get_meta("army_index", -1)
		if index >= 0 and index < game.player.units.size():
			unit = game.player.units[index]
	row.visible = unit != null
	_refresh_upgrade_button(unit)
	if unit == null:
		return
	var title := _label("Items", 11, Color(0.6, 0.6, 0.66))
	title.tooltip_text = "Drag or click a Shard to take it off; Keepsakes stay on.\nDrop items here to equip this unit."
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(title)
	_accept_drops(row, func(): return {"to": "unit", "unit": unit})
	if unit.items.is_empty():
		row.add_child(_label("(none)", 11, Color(0.55, 0.55, 0.6)))
	for i in unit.items.size():
		var button := _item_button(unit.items[i])
		button.disabled = not unit.items[i].is_shard
		var item: Keepsake = unit.items[i]
		button.pressed.connect(func(): game.shard_to_inventory({"from": "unit", "unit": unit, "index": i}))
		_on_right_click(button, func(): game.shard_to_table({"from": "unit", "unit": unit, "index": i}))
		_wire_item(button, func(): return {"from": "unit", "unit": unit, "index": i}, func(): return {"to": "unit", "unit": unit})
		row.add_child(button)


func _refresh_table() -> void:
	for slot in 2:
		var item: Keepsake = game.table[slot]
		_table_slots[slot].icon = item.get_icon() if item != null else null
		_table_slots[slot].text = "" if item != null else "+"
		_table_slots[slot].tooltip_text = "" if item != null else "Drag a Shard here"
	var result := game.table_preview()
	_combine.disabled = result == null
	_table_result.texture = result.get_icon() if result != null else null
	_table_result.tooltip_text = "" if result != null \
			else "Drag two Shards onto the table to see what they make."
	_place_table_window.call_deferred()   # once the side panel has laid itself out


func _refresh_hint() -> void:
	if game.held.has("item"):
		_hint.text = "Holding %s: click a unit to equip it (right-click to cancel)." % \
				game.player.inventory[game.held["item"]].get_display_name()
	elif game.held.has("bench"):
		_hint.text = "Placing %s: click a cell on your half (right-click to cancel)." % game.held["bench"].label()
	else:
		_hint.text = "Drag your units to rearrange them. Click a unit (or right-click it on the bench) to upgrade it."
