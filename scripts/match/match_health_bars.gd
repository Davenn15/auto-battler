class_name MatchHealthBars
extends Control
## The two players' health bars: the opponent's above the board, yours below it, each
## showing "HP / max". After a fight, play_damage() runs the damage animation: the
## winner's health bar and each of their surviving units send a pip to an orb at the
## board's centre (the bar's pip carries the round damage, a unit's pip its Aura), the orb
## shows the total and launches at the loser's bar, which drops when it hits. On a draw
## both orbs form and cross. Purely visual: the damage itself is already applied.
## A bar whose player would die to losing their next combat (even with no enemy survivors)
## glows a slow red pulse. An orb that kills shatters the bar.

const BAR_SIZE := Vector2(300, 16)
## Gap between the board and each bar (the same above and below).
const BOARD_GAP := 12.0
## Bars' vertical centres, in HUD coordinates: BOARD_GAP above and below the board.
const TOP_Y := MatchGame.BOARD_TOP - BOARD_GAP - BAR_SIZE.y / 2.0
const BOTTOM_Y := MatchGame.BOARD_BOTTOM + BOARD_GAP + BAR_SIZE.y / 2.0
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
const DANGER_GLOW := Color(1.0, 0.12, 0.08)
const DANGER_PERIOD := 1.6   # seconds per pulse of the low-health glow
const SHATTER_TIME := 1.0

var max_hp := MatchRules.START_HP
## What each bar shows. Normally the real HP; held at the old value until an orb hits.
var _shown := {true: MatchRules.START_HP, false: MatchRules.START_HP}   # true = yours
var _names := {true: "You", false: "Opponent"}
var _holding := false
var _font: Font
## Per bar (true = yours): would losing the next combat kill this player?
var _danger := {true: false, false: false}
## Per bar: shattered by a killing orb (not drawn any more).
var _shattered := {true: false, false: false}
var _time := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()


## Sets both bars from the players (skipped while an animation holds them).
## `next_combat_round`: the round of the next combat, for the low-health glow (a player
## glows when even the smallest loss then, its round damage alone, would kill them).
func show_players(mine: PlayerState, theirs: PlayerState, next_combat_round: int) -> void:
	_names[true] = mine.player_name
	_names[false] = theirs.player_name
	if not _holding:
		_shown[true] = maxi(mine.hp, 0)
		_shown[false] = maxi(theirs.hp, 0)
	var lethal := MatchRules.round_damage(next_combat_round)
	_danger[true] = mine.hp > 0 and mine.hp <= lethal
	_danger[false] = theirs.hp > 0 and theirs.hp <= lethal
	set_process(_danger[true] or _danger[false])
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## The centre of a bar: yours (below the board) or theirs (above).
func bar_center(mine: bool) -> Vector2:
	return Vector2(MatchGame.board_screen_center.x, BOTTOM_Y if mine else TOP_Y)


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
	var orb_at := MatchGame.board_screen_center + Vector2((index - (count - 1) / 2.0) * 70.0, 0)
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
	if hit["hp_after"] <= 0:
		await _shatter(hit_mine)
	running[0] -= 1


## A killing blow: the bar breaks into pieces that fly apart and fall, then it's gone.
func _shatter(mine: bool) -> void:
	_shattered[mine] = true
	_danger[mine] = false
	queue_redraw()
	var shatter := Shatter.new()
	shatter.setup(Rect2(bar_center(mine) - BAR_SIZE / 2.0, BAR_SIZE).grow(2.0), MINE if mine else THEIRS)
	add_child(shatter)
	await get_tree().create_timer(SHATTER_TIME).timeout


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
	if _shattered[mine]:
		return
	var rect := Rect2(bar_center(mine) - BAR_SIZE / 2.0, BAR_SIZE)
	if _danger[mine]:
		_draw_danger_glow(rect)
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


## The low-health warning: a soft red glow around the bar that slowly swells and fades.
func _draw_danger_glow(rect: Rect2) -> void:
	var pulse := 0.5 - 0.5 * cos(_time * TAU / DANGER_PERIOD)   # 0 -> 1 -> 0
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(DANGER_GLOW, 0.0)
	glow.shadow_color = Color(DANGER_GLOW, lerpf(0.25, 0.8, pulse))
	glow.shadow_size = roundi(lerpf(6.0, 12.0, pulse))
	glow.set_corner_radius_all(3)
	draw_style_box(glow, rect.grow(2.0))


## A shattered health bar: shards of it (some still in the bar's colour) burst out from
## where the orb hit, spin, fall and fade, after a white flash.
class Shatter extends Node2D:
	const GRAVITY := 520.0
	var _pieces: Array = []   # {poly, pos, vel, rot, spin, color}
	var _time := 0.0
	var _rect: Rect2

	func setup(rect: Rect2, color: Color) -> void:
		_rect = rect
		var columns := 10
		var rows := 2
		var w := rect.size.x / columns
		var h := rect.size.y / rows
		for cx in columns:
			for cy in rows:
				var center := rect.position + Vector2((cx + 0.5) * w, (cy + 0.5) * h)
				# A slightly ragged quad, so it reads as broken glass rather than a grid.
				var poly := PackedVector2Array()
				for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					poly.append(Vector2(corner.x * w / 2.0, corner.y * h / 2.0) + Vector2(randf_range(-2.0, 2.0), randf_range(-1.5, 1.5)))
				var out := (center - rect.get_center()).normalized()
				var shade: Color = color.lerp(MatchHealthBars.EMPTY, randf_range(0.0, 0.7)) if randf() < 0.6 else MatchHealthBars.BACK.lightened(0.15)
				_pieces.append({"poly": poly, "pos": center, "vel": out * randf_range(80.0, 240.0) + Vector2(0, randf_range(-160.0, -40.0)),
						"rot": 0.0, "spin": randf_range(-9.0, 9.0), "color": shade})

	func _ready() -> void:
		z_index = 32

	func _process(delta: float) -> void:
		_time += delta
		for piece in _pieces:
			piece["vel"].y += GRAVITY * delta
			piece["pos"] += piece["vel"] * delta
			piece["rot"] += piece["spin"] * delta
		if _time >= MatchHealthBars.SHATTER_TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var fade := clampf(1.0 - _time / MatchHealthBars.SHATTER_TIME, 0.0, 1.0)
		if _time < 0.15:   # the flash where the bar was
			draw_rect(_rect.grow(6.0 * _time / 0.15), Color(1, 1, 1, 0.8 * (1.0 - _time / 0.15)))
		for piece in _pieces:
			draw_set_transform(piece["pos"], piece["rot"])
			draw_colored_polygon(piece["poly"], Color(piece["color"], fade))
		draw_set_transform(Vector2.ZERO, 0.0)


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
