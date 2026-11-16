class_name RoundTrack
extends Control
## The round order in the top bar: the last round, this one and the next three, as icons
## along a line. Player Combat is crossed swords, a Neutral Ascension a circle with an
## upward arrow, a Faction Ascension that faction's emblem (Sword Court: a crown pierced by
## a sword; Obelisk: an eye with circuit nerves). Hover an icon for what it is.

enum Kind { OPENING, COMBAT, NEUTRAL, FACTION, SKIPPED }

const BEFORE := 1   # rounds shown before the current one
const AFTER := 3    # and after it
const SPACING := 50.0
const ICON := 20.0
const CURRENT_SCALE := 1.15

const LINE_COLOR := Color(0.45, 0.45, 0.52)
const COMBAT_COLOR := Color(0.95, 0.45, 0.4)
const NEUTRAL_COLOR := Color(0.85, 0.85, 0.92)
const OPENING_COLOR := Color(0.95, 0.8, 0.35)
const SKIPPED_COLOR := Color(0.4, 0.4, 0.45)
const FACTION_COLORS := {
	"Sword Court": Color(1.0, 0.82, 0.35),
	"Obelisk": Color(0.4, 0.9, 1.0),
}

var round_number := 1
var faction := ""


func _init() -> void:
	custom_minimum_size = Vector2(SPACING * (BEFORE + AFTER + 1), 30)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = " "   # turns tooltips on; the text comes from _get_tooltip


func show_round(p_round: int, p_faction: String) -> void:
	if p_round == round_number and p_faction == faction:
		return
	round_number = p_round
	faction = p_faction
	queue_redraw()


## What round `r` is.
static func kind_of(r: int) -> Kind:
	if r <= 1:
		return Kind.OPENING
	if MatchRules.is_combat_round(r):
		return Kind.COMBAT
	var number := MatchRules.encounter_number(r)
	if MatchRules.encounter_tier(number) > MatchRules.MAX_ASCENSION_TIER:
		return Kind.SKIPPED
	return Kind.FACTION if MatchRules.encounter_kind(number) == MatchRules.EncounterKind.FACTION else Kind.NEUTRAL


func describe(r: int) -> String:
	match kind_of(r):
		Kind.OPENING:
			return "Round %d: Opening Shop" % r
		Kind.COMBAT:
			return "Round %d: Player Combat" % r
		Kind.SKIPPED:
			return "Round %d: no Encounter (all four tiers are done)" % r
	var number := MatchRules.encounter_number(r)
	var title := MatchRules.encounter_title(MatchRules.encounter_kind(number), faction)
	return "Round %d: Tier %d %s" % [r, MatchRules.encounter_tier(number), title]


## The rounds on show, oldest first (no round before the first).
func _shown_rounds() -> Array[int]:
	var result: Array[int] = []
	for r in range(round_number - BEFORE, round_number + AFTER + 1):
		result.append(r)
	return result


func _center_of(index: int) -> Vector2:
	return Vector2(SPACING * (index + 0.5), size.y / 2.0)


func _get_tooltip(at_position: Vector2) -> String:
	var rounds := _shown_rounds()
	var index := clampi(floori(at_position.x / SPACING), 0, rounds.size() - 1)
	if rounds[index] < 1:
		return ""
	var text := describe(rounds[index])
	if rounds[index] == round_number:
		text += " (now)"
	return text


func _draw() -> void:
	var rounds := _shown_rounds()
	var first := 0
	while first < rounds.size() and rounds[first] < 1:
		first += 1
	if first >= rounds.size():
		return
	draw_line(_center_of(first), _center_of(rounds.size() - 1), LINE_COLOR, 2.0, true)
	var font := get_theme_default_font()
	for i in range(first, rounds.size()):
		var r := rounds[i]
		var center := _center_of(i)
		var current := r == round_number
		var past := r < round_number
		var icon := ICON * (CURRENT_SCALE if current else 1.0)
		# A disc under each icon hides the line; the current round gets a bright ring.
		var backdrop := Color(0.11, 0.11, 0.14)
		draw_circle(center, icon * 0.58, backdrop)
		if current:
			draw_arc(center, icon * 0.6, 0.0, TAU, 32, Color(1.0, 0.85, 0.4), 2.0, true)
		var color := color_of(kind_of(r), faction)
		if past:
			color = color.darkened(0.5)
		draw_icon(self, kind_of(r), faction, center, icon * 0.8, color)
		# The tier, in small print, for Ascensions.
		if kind_of(r) in [Kind.NEUTRAL, Kind.FACTION] and font != null:
			var tier := str(MatchRules.encounter_tier(MatchRules.encounter_number(r)))
			var at := center + Vector2(icon * 0.42, icon * 0.55)
			draw_string_outline(font, at, tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, backdrop)
			draw_string(font, at, tier, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


static func color_of(kind: Kind, p_faction: String) -> Color:
	match kind:
		Kind.OPENING:
			return OPENING_COLOR
		Kind.COMBAT:
			return COMBAT_COLOR
		Kind.NEUTRAL:
			return NEUTRAL_COLOR
		Kind.FACTION:
			return FACTION_COLORS.get(p_faction, NEUTRAL_COLOR)
	return SKIPPED_COLOR


# ---------- The icons (drawn, so they stay crisp at any size) ----------

## Draws the icon for `kind` on `canvas`, `size` across, centred on `center`.
static func draw_icon(canvas: CanvasItem, kind: Kind, p_faction: String, center: Vector2, size: float, color: Color) -> void:
	match kind:
		Kind.OPENING:
			_draw_bag(canvas, center, size, color)
		Kind.COMBAT:
			_draw_swords(canvas, center, size, color)
		Kind.NEUTRAL:
			_draw_ascend(canvas, center, size, color)
		Kind.FACTION:
			if p_faction == "Obelisk":
				_draw_eye(canvas, center, size, color)
			else:
				_draw_crown(canvas, center, size, color)
		Kind.SKIPPED:
			canvas.draw_arc(center, size * 0.18, 0.0, TAU, 16, color, 1.5, true)


## Two crossed swords.
static func _draw_swords(canvas: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var h := s / 2.0
	for side in [-1.0, 1.0]:
		var tip := c + Vector2(-side * h, -h)
		var hilt := c + Vector2(side * h * 0.62, h * 0.62)
		canvas.draw_line(tip, hilt, color, maxf(s * 0.11, 1.5), true)
		var along := (hilt - tip).normalized()
		var across := Vector2(-along.y, along.x)
		var guard := hilt - along * s * 0.08
		canvas.draw_line(guard - across * s * 0.17, guard + across * s * 0.17, color, maxf(s * 0.09, 1.5), true)
		canvas.draw_line(hilt, hilt + along * s * 0.16, color, maxf(s * 0.1, 1.5), true)


## A circle with an upward arrow inside.
static func _draw_ascend(canvas: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var r := s / 2.0
	var width := maxf(s * 0.09, 1.5)
	canvas.draw_arc(c, r, 0.0, TAU, 32, color, width, true)
	canvas.draw_line(c + Vector2(0, r * 0.55), c + Vector2(0, -r * 0.45), color, width, true)
	var head := PackedVector2Array([c + Vector2(0, -r * 0.62), c + Vector2(-r * 0.38, -r * 0.18), c + Vector2(r * 0.38, -r * 0.18)])
	canvas.draw_colored_polygon(head, color)


## Sword Court: a crown with a sword piercing down through it.
static func _draw_crown(canvas: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var h := s / 2.0
	var crown := PackedVector2Array([
		c + Vector2(-h * 0.8, h * 0.55), c + Vector2(-h * 1.0, -h * 0.45), c + Vector2(-h * 0.45, -h * 0.05),
		c + Vector2(0.0, -h * 0.6), c + Vector2(h * 0.45, -h * 0.05), c + Vector2(h * 1.0, -h * 0.45),
		c + Vector2(h * 0.8, h * 0.55)])
	canvas.draw_colored_polygon(crown, color)
	# The sword: pommel and guard above the crown, blade through it and out below.
	var dark := Color(0.11, 0.11, 0.14)
	var steel := Color(0.92, 0.94, 1.0, color.a).lerp(color, 0.15)
	if color.v < 0.6:   # a past round: dim the steel too
		steel = steel.darkened(0.5)
	var width := maxf(s * 0.08, 1.2)
	canvas.draw_line(c + Vector2(0, -h * 0.7), c + Vector2(0, h * 1.0), dark, width + 1.6, true)
	canvas.draw_line(c + Vector2(0, -h * 0.7), c + Vector2(0, h * 0.95), steel, width, true)
	canvas.draw_line(c + Vector2(-h * 0.28, -h * 0.68), c + Vector2(h * 0.28, -h * 0.68), steel, width, true)
	canvas.draw_circle(c + Vector2(0, -h * 0.92), s * 0.06, steel)


## Obelisk: an eye with circuit-like nerves running out from it.
static func _draw_eye(canvas: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var h := s / 2.0
	var width := maxf(s * 0.07, 1.2)
	# Nerves: right-angled traces ending in little pads.
	var traces := [
		[Vector2(-0.82, 0.0), Vector2(-1.0, 0.0), Vector2(-1.0, -0.55)],
		[Vector2(0.82, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.55)],
		[Vector2(0.0, -0.42), Vector2(0.0, -0.8), Vector2(0.4, -0.8)],
		[Vector2(0.0, 0.42), Vector2(0.0, 0.8), Vector2(-0.4, 0.8)],
	]
	for trace in traces:
		var points := PackedVector2Array()
		for p in trace:
			points.append(c + p * h)
		canvas.draw_polyline(points, Color(color, 0.8), width, true)
		canvas.draw_circle(points[points.size() - 1], width * 0.9, color)
	# The eye: an almond outline, an iris and a pupil.
	var outline := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		outline.append(c + Vector2(lerpf(-0.82, 0.82, t) * h, -sin(t * PI) * 0.45 * h))
	for i in range(1, 16):
		var t := 1.0 - float(i) / 16.0
		outline.append(c + Vector2(lerpf(-0.82, 0.82, t) * h, sin(t * PI) * 0.45 * h))
	canvas.draw_colored_polygon(outline, Color(0.11, 0.11, 0.14))
	outline.append(outline[0])
	canvas.draw_polyline(outline, color, width, true)
	canvas.draw_circle(c, h * 0.3, color)
	canvas.draw_circle(c, h * 0.12, Color(0.11, 0.11, 0.14))


## The Opening Shop: a coin purse.
static func _draw_bag(canvas: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var h := s / 2.0
	canvas.draw_circle(c + Vector2(0, h * 0.2), h * 0.62, color)
	var neck := PackedVector2Array([c + Vector2(-h * 0.25, -h * 0.4), c + Vector2(h * 0.25, -h * 0.4),
			c + Vector2(h * 0.45, -h * 0.8), c + Vector2(-h * 0.45, -h * 0.8)])
	canvas.draw_colored_polygon(neck, color)
	canvas.draw_line(c + Vector2(-h * 0.3, -h * 0.42), c + Vector2(h * 0.3, -h * 0.42), Color(0.11, 0.11, 0.14), maxf(s * 0.08, 1.2), true)
