class_name Keyphrases
extends RefCounted
## Turns a plain description into BBCode with its keyphrases highlighted: each Shard
## stat in that stat's colour, with the stat's icon in front of it, and a few other terms
## (Charge, regen) in their own colour. Descriptions stay plain text in the data; whatever
## shows one runs it through format() first (it needs a RichTextLabel with BBCode on).

const ICON_DIR := "res://assets/icons/stats/"
## Icon size in the text, in pixels.
const ICON_SIZE := 12

## Each keyphrase: its colour (a Shard, or a named colour from extra_color), its icon (""
## for none), and the pattern that finds it. Checked as one pattern, longest first, so
## "Might Ward" wins over "Might" and "Charge Regen" over "Charge".
const PHRASES := [
	[Shard.Kind.MIGHT_WARD, "might_ward", "\\bMight [Ww]ards?\\b"],
	[Shard.Kind.CELERITY_WARD, "celerity_ward", "\\bCelerity [Ww]ards?\\b"],
	[Shard.Kind.INSIGHT_WARD, "insight_ward", "\\bInsight [Ww]ards?\\b"],
	[Shard.Kind.WRACK, "wrack", "\\b(?i:(?:Hyper|Uber)-Wrack(?:s|ed|ing)?|Wrack(?:s|ed|ing)?(?: Chance| Damage)?)\\b"],
	# Capital C only: the mechanic is always written "Charge"; lowercase "charge" is just
	# the ordinary word (Scour's beam "takes a moment to charge up").
	["charge", "", "\\bCharge(?: [Rr]egen)?\\b"],
	# Gambit, in the same pink as Charge: capital G only, like Charge.
	["gambit", "", "\\bGambits?\\b"],
	# The Beam keyword (see Beam): capital B only, so the ordinary word isn't coloured.
	["beam", "", "\\bBeams?\\b"],
	# The Hinder debuff (see HinderStatus).
	["hinder", "", "\\bHinder(?:s|ed|ing)?\\b"],
	# The Bleed keyword (see Bleed): capital B only, like the other keywords.
	["bleed", "", "\\bBleed(?:s|ing)?\\b"],
	# Pure Damage: damage that ignores every Ward (Stats.DamageType.PURE).
	["pure", "", "\\bPure [Dd]amage\\b"],
	# The Silence keyword (see Silence): no Gambit, no Charge.
	["silence", "", "\\bSilenc(?:e|es|ed|ing)\\b"],
	# The Grit keyword (see Grit): part of each hit spread over a few seconds.
	["grit", "", "\\bGrit\\b"],
	# The Scar keyword (see Scar): part of each hit healed back a few seconds later.
	["scar", "", "\\bScar\\b"],
	# The Voltage keyword (see VoltageStatus): stacks of Insight and Celerity. Capital V only.
	["voltage", "", "\\bVoltage\\b"],
	# The Knock-up keyword (see KnockUp): thrown into the air, stunned.
	["knockup", "", "\\b(?:Knock-ups?|Knock(?:s|ed|ing)? up|knock(?:s|ed|ing)? up)\\b"],
	# Immovability (Stats.Stat.IMMOVABILITY): shorter crowd control and debuffs.
	["immovability", "", "\\bImmovability\\b"],
	[Shard.Kind.HEALTH, "health", "\\b(?i:max(?:imum)? health|health)\\b"],
	["regen", "", "\\b(?i:regen(?:eration)?)\\b"],
	[Shard.Kind.MIGHT, "might", "\\bMight\\b"],
	[Shard.Kind.CELERITY, "celerity", "\\bCelerity\\b"],
	[Shard.Kind.INSIGHT, "insight", "\\bInsight\\b"],
]

## The Beam keyword's colour: a bright beam cyan.
const BEAM_COLOR := Color(0.45, 0.95, 1.0)
## Immovability's colour: a sandy stone.
const IMMOVABILITY_COLOR := Color(0.85, 0.74, 0.55)

static var _regex: RegEx
static var _new_gambit: RegEx
## Font size of the NEW GAMBIT tag over a new Gambit's name.
const NEW_GAMBIT_TAG_SIZE := 10


## The colour a stat's name is shown in: its Shard's colour, lightened to read on the dark
## panels (the same as the unit info panel's stat table).
static func color_of(kind: Shard.Kind) -> Color:
	return (Shard.COLORS[kind] as Color).lightened(0.3)


## Colours for keyphrases that aren't Shard stats: Charge and Gambit are the pink of the
## casting bar, regen the same green as Health, Beam a bright cyan.
static func extra_color(key: String) -> Color:
	match key:
		"charge", "gambit":
			return BattleUnit.CASTING_COLOR
		"regen":
			return color_of(Shard.Kind.HEALTH)
		"beam":
			return BEAM_COLOR
		"hinder":
			return HinderStatus.TINT.lightened(0.25)
		"bleed":
			return Bleed.COLOR.lightened(0.25)
		"pure":
			return Stats.DAMAGE_TYPE_COLORS[Stats.DamageType.PURE]
		"immovability":
			return IMMOVABILITY_COLOR
		"silence":
			return Silence.COLOR
		"grit":
			return Grit.COLOR
		"scar":
			return Scar.COLOR
		"knockup":
			return KnockUp.COLOR
		"voltage":
			return VoltageStatus.LIGHT
	return Color.WHITE


static func _phrase_color(phrase: Array) -> Color:
	return extra_color(phrase[0]) if phrase[0] is String else color_of(phrase[0])


static func icon_path(kind: Shard.Kind) -> String:
	for phrase in PHRASES:
		if phrase[0] is int and phrase[0] == kind:
			return ICON_DIR + phrase[1] + ".png"
	return ""


## One Shard stat keyphrase as BBCode: its icon, then the text in its colour.
static func tag(kind: Shard.Kind, text: String) -> String:
	return _tag(color_of(kind), icon_path(kind), text)


## A keyphrase as BBCode: the icon (if any), then the text in `color`. The icon and every
## word of the phrase stay on one line.
static func _tag(color: Color, icon: String, text: String) -> String:
	var out := ""
	if icon != "":
		out = "[img=%dx%d]%s[/img]⁠" % [ICON_SIZE, ICON_SIZE, icon]
	return out + "[color=%s]%s[/color]" % [color.to_html(false), text.replace(" ", " ")]


## `text` with every keyphrase highlighted. Square brackets in it are escaped, so plain
## text can't be read as BBCode by accident.
## `text` uncoloured (for upgrades not taken yet), but with a new Gambit still laid out as
## a small NEW GAMBIT tag, the name as a title, then the rest. Square brackets escaped.
static func plain(text: String, ctx: DescriptionContext = null) -> String:
	if ctx != null or text.contains("{"):
		return _with_numbers(text, ctx, true)
	if _new_gambit == null:
		_new_gambit = RegEx.create_from_string("^New Gambit: ([^.]+)\\.\\s*")
	var found := _new_gambit.search(text)
	if found == null:
		return _escape(text)
	return "NEW GAMBIT\n[b]%s[/b]\n%s" % [_escape(found.get_string(1)), _escape(text.substr(found.get_end()))]


static func format(text: String, ctx: DescriptionContext = null) -> String:
	if text == "":
		return text
	if ctx != null or text.contains("{"):
		return _with_numbers(text, ctx, false)
	# "New Gambit: Name. The rest." (B upgrades) reads as a small pink NEW GAMBIT tag, the
	# Gambit's name as a title, then the rest.
	if _new_gambit == null:
		_new_gambit = RegEx.create_from_string("^New Gambit: ([^.]+)\\.\\s*")
	var found := _new_gambit.search(text)
	if found != null:
		return "[font_size=%d][color=%s]NEW GAMBIT[/color][/font_size]\n[b]%s[/b]\n%s" % [NEW_GAMBIT_TAG_SIZE,
				extra_color("gambit").to_html(false), _escape(found.get_string(1)), _format_words(text.substr(found.get_end()))]
	return _format_words(text)


## The keyphrase highlighting alone, for text with no number placeholders.
static func _format_words(text: String) -> String:
	if _regex == null:
		var parts: PackedStringArray = []
		for phrase in PHRASES:
			parts.append("(%s)" % phrase[2])
		_regex = RegEx.create_from_string("|".join(parts))
	var out := ""
	var at := 0
	for m in _regex.search_all(text):
		out += _escape(text.substr(at, m.get_start() - at))
		for i in PHRASES.size():
			if m.get_string(i + 1) != "":
				var phrase: Array = PHRASES[i]
				var icon: String = (ICON_DIR + phrase[1] + ".png") if phrase[1] != "" else ""
				out += _tag(_phrase_color(phrase), icon, m.get_string())
				break
		at = m.get_end()
	return out + _escape(text.substr(at))


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


# ---------- Numbers in descriptions ----------
# A description can hold placeholders for its numbers, filled in from the ability it
# describes (see DescriptionContext), so the text always shows the real values:
#   {damage}                 the value: "200" (whole numbers without decimals)
#   {damage_share%}          a share as a percentage: 0.3 -> "30%"
#   {damage+might_scaling}   with the unit's stats (a context with stats): the current
#                            number, then how it got there, small and dimmed:
#                            "356 (200 + icon 120%)". Without stats: "200 (icon 120%)".
#                            Several scalings: {damage+might_scaling+insight_scaling}.
# A scaling's stat comes from its name (might, insight, celerity); write "name:might" to say
# it outright. Tags after a "|" say what kind of number it is, so the unit's boosts apply:
#   |maxhp      a share of the unit's own max health: "330 (30% max health)"
#   |shield     a shield it gives (shield boosts: Manalyzer, Saviour...)
#   |heal       a heal it gives (heal boosts)
#   |shieldtime how long a shield it gives lasts
#   |cc         how long a crowd control or debuff it applies lasts
# e.g. {shield_share%|maxhp|shield}. A placeholder that can't be filled shows as "?".

## The breakdown is italic and dimmer than the text. Its size is the label's italics font
## size: labels that show descriptions set it a little under their text (see style_label).
const SCALING_ICON_SIZE := 10
const SCALING_COLOR := Color(0.62, 0.63, 0.7)
const STAT_WORDS := {"might": Shard.Kind.MIGHT, "insight": Shard.Kind.INSIGHT,
		"celerity": Shard.Kind.CELERITY, "health": Shard.Kind.HEALTH}
const STAT_OF_WORD := {"might": Stats.Stat.MIGHT, "insight": Stats.Stat.INSIGHT,
		"celerity": Stats.Stat.CELERITY}
const TIME_TAGS := ["cc", "shieldtime"]

static var _placeholder: RegEx


static func _placeholder_regex() -> RegEx:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{([A-Za-z0-9_.:+%|]+)\\}")
	return _placeholder


## `text` with its placeholders filled from `ctx` and its keyphrases highlighted (or left
## plain, for `plain`). The "New Gambit: Name." opening keeps its layout.
static func _with_numbers(text: String, ctx: DescriptionContext, uncoloured: bool) -> String:
	if _new_gambit == null:
		_new_gambit = RegEx.create_from_string("^New Gambit: ([^.]+)\\.\\s*")
	var found := _new_gambit.search(text)
	if found != null:
		var tag := "NEW GAMBIT" if uncoloured else "[color=%s]NEW GAMBIT[/color]" % extra_color("gambit").to_html(false)
		return "[font_size=%d]%s[/font_size]\n[b]%s[/b]\n%s" % [NEW_GAMBIT_TAG_SIZE, tag,
				_escape(found.get_string(1)), _with_numbers(text.substr(found.get_end()), ctx, uncoloured)]
	var out := ""
	var at := 0
	var singular_next := false
	for m in _placeholder_regex().search_all(text):
		var words := _singular(text.substr(at, m.get_start() - at)) if singular_next else text.substr(at, m.get_start() - at)
		out += _escape(words) if uncoloured else _format_words(words)
		var number := _evaluate(m.get_string(1), ctx)
		var damage_type := _damage_type_after(text.substr(m.get_end(), 40), ctx)
		if damage_type >= 0 and number["main"] != "" and not uncoloured:   # a damage number: its type's colour
			number["main"] = "[color=%s]%s[/color]" % [Stats.DAMAGE_TYPE_COLORS[damage_type].to_html(false), number["main"]]
		out += _rich_number(number)
		singular_next = _plain_number(number["main"]) == "1" and number["parts"].is_empty()   # "1 cell", not "1 cells"
		at = m.get_end()
	var rest := _singular(text.substr(at)) if singular_next else text.substr(at)
	return out + (_escape(rest) if uncoloured else _format_words(rest))


## Works out one placeholder: {"main": the number to show ("" when only the breakdown
## shows), "parts": the breakdown's pieces as [text, stat word or ""]}.
static func _evaluate(token: String, ctx: DescriptionContext) -> Dictionary:
	var tags := token.split("|")
	var parts := tags[0].split("+")
	tags = tags.slice(1)
	var percent := parts[0].ends_with("%")
	var base_value: Variant = ctx.lookup(parts[0].trim_suffix("%")) if ctx != null else null
	if base_value == null:
		push_warning("Description placeholder {%s} has nothing to read from." % token)
		return {"main": "?", "parts": []}
	var base := float(base_value)
	var scalings: Array = []   # [share, stat word]
	for part in parts.slice(1):
		var bits := part.split(":")
		var value: Variant = ctx.lookup(bits[0])
		if value == null:
			return {"main": "?", "parts": []}
		if not is_zero_approx(float(value)):
			scalings.append([float(value), bits[1] if bits.size() > 1 else _stat_word(bits[0])])
	var boosts: Array = []   # [multiplier, source Keepsake or null]
	if ctx != null:
		for tag in tags:
			match tag:
				"shield": boosts.append_array(ctx.support_boosts(true))
				"heal": boosts.append_array(ctx.support_boosts(false))
				"cc": boosts.append_array(ctx.control_boosts())
				"shieldtime": boosts.append_array(ctx.shield_time_boosts())
	var multiplier := 1.0
	for boost in boosts:
		multiplier *= boost[0]
	var timed := "cc" in tags or "shieldtime" in tags
	var stats := ctx != null and ctx.has_stats()
	var base_text := _number(base * 100.0) + "%" if percent else _number(base)
	var bonus: Array = []   # each boost, marked with its source's icon
	for boost in boosts:
		var source = boost[1]
		bonus.append([_number((boost[0] - 1.0) * 100.0) + "%", source if source is Keepsake else "boost"])
	if "maxhp" in tags and stats:
		var current := base * ctx.max_health * multiplier
		return {"main": _current(current, timed), "parts": [[_number(base * 100.0) + "% max health", ""]] + bonus}
	var scaling_parts: Array = []
	for s in scalings:
		scaling_parts.append([_number(s[0] * 100.0) + "%", s[1]])
	if not scalings.is_empty() and stats:
		var current := base
		for s in scalings:
			current += s[0] * float(ctx.stats.get(STAT_OF_WORD.get(s[1], -1), 0.0))
		current *= multiplier
		var shown: Array = [] if is_zero_approx(base) else [[base_text, ""]]
		return {"main": _current(current, timed), "parts": shown + scaling_parts + bonus}
	if not scalings.is_empty():   # no unit: the base and the scaling, as written
		return {"main": "" if is_zero_approx(base) else base_text, "parts": scaling_parts, "no_plus": true}
	if not bonus.is_empty():
		var value := base * multiplier
		var main := _number(value * 100.0) + "%" if percent else _current(value, timed)
		return {"main": main, "parts": [[base_text, ""]] + bonus}
	return {"main": base_text, "parts": []}


## A current number: whole numbers for amounts of 10 or more, two decimals for durations
## and small numbers.
static func _current(value: float, timed: bool) -> String:
	if timed or absf(value) < 10.0:
		return _number(value)
	return str(roundi(value))


## The evaluated number as BBCode: the main number, then the breakdown small and dimmed,
## each scaling as its stat's icon and percentage ("356 (200 + icon120%)").
static func _rich_number(number: Dictionary) -> String:
	var parts: Array = number["parts"]
	if parts.is_empty():
		return number["main"]
	var pieces: PackedStringArray = []
	for part in parts:
		var icon := ""
		if part[1] is Keepsake:   # a Keepsake's boost: its icon (its name on hover)
			icon = "[hint=%s][img=%dx%d]%s[/img][/hint]" % [part[1].get_display_name(), SCALING_ICON_SIZE, SCALING_ICON_SIZE, part[1].icon_path()]
		elif part[1] is String and part[1] == "boost":
			icon = "[hint=A boost][color=#d8c070]▲[/color][/hint]"
		elif STAT_WORDS.has(part[1]):
			var kind: Shard.Kind = STAT_WORDS[part[1]]
			icon = "[hint=%s][img=%dx%d]%s[/img][/hint]" % [Shard.NAMES[kind], SCALING_ICON_SIZE, SCALING_ICON_SIZE, icon_path(kind)]
		pieces.append(icon + part[0])
	var joiner := " " if number.get("no_plus", false) else " + "
	var small := "[i][color=%s](%s)[/color][/i]" % [SCALING_COLOR.to_html(false), joiner.join(pieces)]
	if number["main"] == "":
		return small
	return number["main"] + char(160) + small   # never wraps away from its number


## The stat a scaling property is for, from its name ("pop_might_scaling" -> "might").
static func _stat_word(property: String) -> String:
	for word in STAT_WORDS:
		if property.contains(word):
			return word
	return ""


## "200" for whole numbers, "2.5" or "0.75" otherwise.
static func _number(value: float) -> String:
	var rounded := snappedf(value, 0.01)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return String.num(rounded, 2).rstrip("0").rstrip(".")


## Plural words a number placeholder may come before; after a 1 they read singular.
const SINGULARS := {"cells": "cell", "seconds": "second", "stacks": "stack", "enemies": "enemy",
		"allies": "ally", "missiles": "missile", "bubbles": "bubble", "times": "time",
		"targets": "target", "hits": "hit", "attacks": "attack", "units": "unit", "copies": "copy",
		"blades": "blade", "beams": "beam", "Beams": "Beam", "bolts": "bolt", "shots": "shot", "charges": "charge"}


## `text` with its first word made singular, if it's one of SINGULARS (" cells..." -> " cell...").
static func _singular(text: String) -> String:
	var trimmed := text.lstrip(" ")
	for plural in SINGULARS:
		if trimmed.begins_with(plural) and (trimmed.length() == plural.length() or not trimmed[plural.length()].is_valid_identifier()):
			return text.substr(0, text.length() - trimmed.length()) + SINGULARS[plural] + trimmed.substr(plural.length())
	return text


## `text` with its number placeholders filled in as plain text (no BBCode): "356 (200 +
## 120% Might)". For plain tooltips.
static func resolve_plain(text: String, ctx: DescriptionContext) -> String:
	if not text.contains("{"):
		return text
	var out := ""
	var at := 0
	var singular_next := false
	for m in _placeholder_regex().search_all(text):
		var words := text.substr(at, m.get_start() - at)
		out += _singular(words) if singular_next else words
		var number := _evaluate(m.get_string(1), ctx)
		var pieces: PackedStringArray = []
		for part in number["parts"]:
			var label := ""
			if part[1] is Keepsake:
				label = " " + part[1].get_display_name()
			elif part[1] is String and part[1] != "" and part[1] != "boost":
				label = " " + String(part[1]).capitalize()
			pieces.append(part[0] + label)
		var piece: String = number["main"]
		if not pieces.is_empty():
			var joined := (" " if number.get("no_plus", false) else " + ").join(pieces)
			piece = ("(%s)" % joined) if piece == "" else "%s (%s)" % [piece, joined]
		singular_next = number["main"] == "1" and pieces.is_empty()
		out += piece
		at = m.get_end()
	var rest := text.substr(at)
	return out + (_singular(rest) if singular_next else rest)


## The damage type of a number followed by `after`: "... Insight damage" says it outright,
## "... Pure Damage" is Pure, and a bare "... damage" is the ability's own damage type
## (its damage_type). -1 when it isn't a damage number (or the type isn't known).
static func _damage_type_after(after: String, ctx: DescriptionContext) -> int:
	if _damage_after == null:
		_damage_after = RegEx.create_from_string("^\\s+(?:(Might|Insight|Celerity)\\s+)?(Pure\\s+)?[Dd]amage\\b")
	var m := _damage_after.search(after)
	if m == null:
		return -1
	match m.get_string(1):
		"Might": return Stats.DamageType.MIGHT
		"Insight": return Stats.DamageType.INSIGHT
		"Celerity": return Stats.DamageType.CELERITY
	if m.get_string(2) != "":
		return Stats.DamageType.PURE
	var own: Variant = ctx.lookup("damage_type") if ctx != null else null
	return int(own) if own != null else -1

static var _damage_after: RegEx


## `text` without BBCode tags ("[color=...]1[/color]" -> "1").
static func _plain_number(text: String) -> String:
	return RegEx.create_from_string("\\[[^\\]]*\\]").sub(text, "", true)


## Sets up a RichTextLabel that shows descriptions: its italics (the number breakdowns) a
## little smaller than its text. Call again when its text size changes.
static func style_label(label: RichTextLabel, text_size: int) -> void:
	label.add_theme_font_size_override("italics_font_size", maxi(text_size - 2, 6))
