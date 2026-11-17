class_name MatchHealthBars
extends Control
## The two players' health bars: the opponent's above the board, yours below it, each
## showing "HP / max". After a fight, play_damage() runs the damage animation: the
## winner's health bar and each of their surviving units send a pip to an orb at the
## board's centre (the bar's pip carries the round damage, a unit's pip its Aura), the orb
## shows the total and launches at the loser's bar, which drops when it hits. On a draw
## both orbs form and cross. Purely visual: the damage itself is already applied.

const BAR_SIZE := Vector2(300, 16)
## Bars' vertical centres, in HUD coordinates: just above and just below the board.
const TOP_Y := 68.0
const BOTTOM_Y := 540.0   # the board ends at about 530; the Ascension badges start at 552
const BACK := Color(0.09, 0.09, 0.11, 0.92)
const BORDER := Color(0.38, 0.38, 0.44)
const EMPTY := Color(0.2, 0.08, 0.08)
const MINE := Color(0.4, 0.65, 1.0)     # your colour (blue), as in the top bar
const THEIRS := Color(1.0, 0.4, 0.4)    # the opponent's (red)
const ROUND_PIP := Color(1.0, 0.85, 0.4)
const AURA_PIP := Color(0.45, 0.85, 1.0)
const ORB_COLOR := Color(1.0, 0.55, 0.25)

const PIP_TIME := 0.5     # a pip's flight to the orb
const PIP_STAGGER := 0.07
const GATHER_TIME := 0.35  # the orb holding its total before launching
const LAUNCH_TIME := 0.45
const DRAIN_TIME := 0.4

var max_hp := MatchRules.START_HP
## What each bar shows. Normally the real HP; held at the old value until an orb hits.
var _shown := {true: MatchRules.START_HP, false: MatchRules.START_HP}   # true = yours
var _names := {true: "You", false: "Opponent"}
var _holding := false
var _font: Font


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()


## Sets both bars from the players (skipped while an animation holds them).
func show_players(mine: PlayerState, theirs: PlayerState) -> void:
	_names[true] = mine.player_name
	_names[false] = theirs.player_name
	if not _holding:
		_shown[true] = maxi(mine.hp, 0)
		_shown[false] = maxi(theirs.hp, 0)
	queue_redraw()


## The centre of a bar: yours (below the board) or theirs (above).
func bar_center(mine: bool) -> Vector2:
	return Vector2(MatchGame.BOARD_SCREEN_CENTER.x, BOTTOM_Y if mine else TOP_Y)


## Holds both bars at these values (true = yours), ignoring show_players, until
## play_damage has run. Headless there's no animation, so nothing is held.
func hold(hp: Dictionary) -> void:
	if not KeepsakeVfx.enabled():
		return
	_holding = true
	_shown[true] = maxi(hp[true], 0)
	_shown[false] = maxi(hp[false], 0)
	queue_redraw()


## Plays the damage animation and waits for it, then lets the bars follow the players
## again. Each hit is {"from_mine": bool (the side sending it), "round_damage": int,
## "survivors": [{"at": Vector2 (screen), "aura": int}], "damage": int, "hp_after": int
## (the target's)}. Two hits play at once (a draw).
func play_damage(hits: Array) -> void:
	if hits.is_empty() or not KeepsakeVfx.enabled():
		_holding = false
		return
	# Both orbs of a draw launch together: everyone waits for the one with the most pips.
	var most_pips := 0
	for hit in hits:
		most_pips = maxi(most_pips, 1 + hit["survivors"].size())
	var gather_wait := PIP_TIME + (most_pips - 1) * PIP_STAGGER + 0.02
	var running := [hits.size()]
	for i in hits.size():
		_play_one(hits[i], i, hits.size(), running, gather_wait)
	while running[0] > 0:
		await get_tree().process_frame
	_holding = false


func _play_one(hit: Dictionary, index: int, count: int, running: Array, gather_wait: float) -> void:
	var from_mine: bool = hit["from_mine"]
	# The orb: at the board's centre, nudged apart when two form at once.
	var orb_at := MatchGame.BOARD_SCREEN_CENTER + Vector2((index - (count - 1) / 2.0) * 70.0, 0)
	var orb := Orb.new()
	orb.color = MINE.lerp(ORB_COLOR, 0.5) if from_mine else THEIRS.lerp(ORB_COLOR, 0.5)
	orb.position = orb_at
	add_child(orb)
	# The pips: the bar's (round damage) first, then each survivor's (its Aura).
	var sources: Array = [{"at": bar_center(from_mine), "text": str(hit["round_damage"]), "color": ROUND_PIP}]
	for survivor in hit["survivors"]:
		sources.append({"at": survivor["at"], "text": str(survivor["aura"]), "color": AURA_PIP})
	var arrived := [0]
	for i in sources.size():
		var pip := Pip.new()
		pip.text = sources[i]["text"]
		pip.color = sources[i]["color"]
		pip.position = sources[i]["at"]
		add_child(pip)
		var tween := pip.create_tween()
		tween.tween_interval(i * PIP_STAGGER)
		tween.tween_property(pip, "position", orb_at, PIP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_pip_arrived.bind(pip, orb, arrived, sources.size()))
	await get_tree().create_timer(gather_wait).timeout
	# The total, then off to the loser's bar.
	orb.text = str(hit["damage"])
	orb.pulse()
	await get_tree().create_timer(GATHER_TIME).timeout
	var target := bar_center(not from_mine)
	var fly := orb.create_tween()
	fly.tween_property(orb, "position", target, LAUNCH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await fly.finished
	orb.burst()
	var hit_mine := not from_mine
	var drain := create_tween()
	drain.tween_method(_set_shown.bind(hit_mine), float(_shown[hit_mine]), float(maxi(hit["hp_after"], 0)), DRAIN_TIME)
	await drain.finished
	running[0] -= 1


func _pip_arrived(pip: Node2D, orb: Orb, arrived: Array, total: int) -> void:
	pip.queue_free()
	arrived[0] += 1
	orb.grow(float(arrived[0]) / total)


func _set_shown(value: float, mine: bool) -> void:
	_shown[mine] = roundi(value)
	queue_redraw()


func _draw() -> void:
	for mine in [false, true]:
		_draw_bar(mine)


func _draw_bar(mine: bool) -> void:
	var rect := Rect2(bar_center(mine) - BAR_SIZE / 2.0, BAR_SIZE)
	draw_rect(rect.grow(2.0), BACK)
	draw_rect(rect, EMPTY)
	var share := clampf(float(_shown[mine]) / max_hp, 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * share, rect.size.y)), MINE if mine else THEIRS)
	draw_rect(rect.grow(2.0), BORDER, false, 1.0)
	if _font == null:
		return
	var text := "%s   %d / %d" % [_names[mine], _shown[mine], max_hp]
	var size := 12
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(rect.get_center().x - width / 2.0, rect.get_center().y + size * 0.35)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.8))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


## A damage pip on its way to the orb: a small glowing dot with its number.
class Pip extends Node2D:
	var text := ""
	var color := Color.WHITE

	func _ready() -> void:
		z_index = 30

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 7.0, Color(color, 0.3))
		draw_circle(Vector2.ZERO, 4.0, color)
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var at := Vector2(-width / 2.0, -9.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


## The damage orb: grows as pips land, shows the total, flies, bursts on the bar.
class Orb extends Node2D:
	var color := Color.ORANGE
	var text := ""
	var _radius := 5.0
	var _time := 0.0
	var _bursting := false
	var _burst := 0.0

	func _ready() -> void:
		z_index = 31

	func grow(share: float) -> void:
		var tween := create_tween()
		tween.tween_property(self, "_radius", lerpf(6.0, 15.0, share), 0.12)

	func pulse() -> void:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ONE * 1.35, 0.1)
		tween.tween_property(self, "scale", Vector2.ONE, 0.15)

	func burst() -> void:
		_bursting = true
		text = ""
		var tween := create_tween()
		tween.tween_property(self, "_burst", 1.0, 0.35)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if _bursting:
			var r := lerpf(_radius, _radius * 4.0, _burst)
			var a := 1.0 - _burst
			draw_circle(Vector2.ZERO, r, Color(color, 0.25 * a))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.95, 0.8, a), 3.0, true)
			return
		var flicker := 1.0 + 0.08 * sin(_time * 18.0)
		draw_circle(Vector2.ZERO, _radius * 1.7 * flicker, Color(color, 0.22))
		draw_circle(Vector2.ZERO, _radius * flicker, color)
		draw_circle(Vector2.ZERO, _radius * 0.55, Color(1.0, 0.95, 0.8))
		if text != "":
			var font := ThemeDB.fallback_font
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var at := Vector2(-width / 2.0, 6.0)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
