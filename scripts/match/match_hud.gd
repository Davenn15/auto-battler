class_name MatchHud
extends Control
## The match screen's panels: a top bar (round, health and money), the planning panel on
## the right (shop, bench, items, the selected unit, the ritual table), the log and the
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
var _table_slots: Array[Button] = []
var _table_preview: Label
var _combine: Button
var _hint: Label
var _log: Label
var _ready_button: Button
var _popup: PanelContainer
var _popup_text: Label
var _popup_buttons: VBoxContainer
var _unit_tip: PanelContainer
var _unit_tip_text: RichTextLabel

const UNIT_TIP_WIDTH := 320.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_side()
	_build_bottom()
	_build_popup()
	_build_unit_tip()


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


func _label(text: String, size: int = 12, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
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
	bench_column.add_child(_label("Click a bench unit, then a cell to place it. Drag a unit here to bench it.", 10, Color(0.65, 0.65, 0.7)))
	_bench = HFlowContainer.new()
	bench_column.add_child(_bench)
	column.add_child(HSeparator.new())

	# Items
	column.add_child(_header("Items"))
	column.add_child(_label("Click an item, then a unit to equip it, or a ritual table slot.", 10, Color(0.65, 0.65, 0.7)))
	_inventory = HFlowContainer.new()
	column.add_child(_inventory)
	_sell = Button.new()
	_sell.pressed.connect(func(): game.sell_held())
	column.add_child(_sell)
	column.add_child(HSeparator.new())

	# Selected unit
	_selected_label = _label("", 12)
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_selected_label)
	_selected_items = HBoxContainer.new()
	column.add_child(_selected_items)
	column.add_child(HSeparator.new())

	# Ritual table
	column.add_child(_header("Ritual table"))
	var slots := HBoxContainer.new()
	column.add_child(slots)
	for slot in 2:
		var button := Button.new()
		button.custom_minimum_size = Vector2(40, 40)
		button.expand_icon = true
		button.pressed.connect(func(): game.table_clicked(slot))
		slots.add_child(button)
		_table_slots.append(button)
	_table_preview = _label("", 11)
	_table_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_table_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_child(_table_preview)
	_combine = Button.new()
	_combine.text = "Combine"
	_combine.pressed.connect(func(): game.combine_table())
	column.add_child(_combine)


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
	var planning := game.phase == MatchGame.Phase.PLANNING
	_side.visible = planning
	_hint.visible = planning
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
		if game.phase == MatchGame.Phase.PLANNING:
			phase_name += " · [color=#ffd24d]%d s left[/color]" % ceili(maxf(game.planning_left, 0.0))
		online_bits = "   [color=#7fdc7f]Ready ✓[/color]" if game.ai_ready else "   [color=#9a9aa5]planning…[/color]"
	_top.text = "[b]Round %d[/b] · %s        [color=#66a6ff][b]You[/b][/color]  HP %d   Aura %d   Reserve %d   [color=#9a9aa5](Aura given %d / %d)[/color]        [color=#ff6666][b]Opponent[/b][/color]  HP %d%s" % [
			game.round_number, phase_name, maxi(p.hp, 0), p.aura, p.reserve, p.aura_received,
			MatchRules.MAX_AURA_RECEIVED, maxi(game.ai.hp, 0), online_bits]


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
		var name := "%s  (tier %d)" % [data.display_name.capitalize(), data.tier]
		match info["kind"]:
			"buy":
				button.text = "%s\nBuy: %d Aura" % [name, info["aura"]]
			"upgrade":
				button.text = "%s\nUpgrade: %d Aura" % [name, info["aura"]]
			"buff":
				button.text = "%s\nBuff stats: %d Reserve" % [name, info["reserve"]]
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
		var button := Button.new()
		button.text = unit.label()
		button.icon = unit.data.sprite
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 30)
		if game.held.get("bench") == unit:
			button.modulate = HELD_COLOR
		button.pressed.connect(func(): game.bench_clicked(unit))
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
	_selected_label.text = "%s's items (click a Shard to take it off; keepsakes stay on):" % unit.label()
	if unit.buffs > 0:
		_selected_label.text = "%s, %d buff%s. Items (click a Shard to take it off):" % [unit.label(), unit.buffs, "" if unit.buffs == 1 else "s"]
	if unit.items.is_empty():
		_selected_items.add_child(_label("(none)", 11, Color(0.55, 0.55, 0.6)))
	for i in unit.items.size():
		var button := _item_button(unit.items[i])
		button.disabled = not unit.items[i].is_shard
		button.pressed.connect(func(): game.unequip(unit, i))
		_selected_items.add_child(button)


func _refresh_table() -> void:
	for slot in 2:
		var item: Keepsake = game.table[slot]
		_table_slots[slot].icon = item.get_icon() if item != null else null
		_table_slots[slot].text = "" if item != null else "+"
		_table_slots[slot].tooltip_text = ItemToolbox.describe(item) if item != null else "Put a Shard here"
	var result := game.table_preview()
	_combine.disabled = result == null
	if result != null:
		_table_preview.text = "Makes %s" % result.get_display_name()
		_table_preview.tooltip_text = ItemToolbox.describe(result)
		_table_preview.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		_table_preview.text = "Put two Shards on the table to see what they make."
		_table_preview.tooltip_text = ""


func _refresh_hint() -> void:
	if game.held.has("item"):
		_hint.text = "Holding %s: click a unit to equip it (right-click to cancel)." % \
				game.player.inventory[game.held["item"]].get_display_name()
	elif game.held.has("bench"):
		_hint.text = "Placing %s: click a cell on your half (right-click to cancel)." % game.held["bench"].label()
	else:
		_hint.text = "Drag your units to rearrange them."
