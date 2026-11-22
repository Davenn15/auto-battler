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
static func plain(text: String) -> String:
	if _new_gambit == null:
		_new_gambit = RegEx.create_from_string("^New Gambit: ([^.]+)\\.\\s*")
	var found := _new_gambit.search(text)
	if found == null:
		return _escape(text)
	return "NEW GAMBIT\n[b]%s[/b]\n%s" % [_escape(found.get_string(1)), _escape(text.substr(found.get_end()))]


static func format(text: String) -> String:
	if text == "":
		return text
	# "New Gambit: Name. The rest." (B upgrades) reads as a small pink NEW GAMBIT tag, the
	# Gambit's name as a title, then the rest.
	if _new_gambit == null:
		_new_gambit = RegEx.create_from_string("^New Gambit: ([^.]+)\\.\\s*")
	var found := _new_gambit.search(text)
	if found != null:
		return "[font_size=%d][color=%s]NEW GAMBIT[/color][/font_size]\n[b]%s[/b]\n%s" % [NEW_GAMBIT_TAG_SIZE,
				extra_color("gambit").to_html(false), _escape(found.get_string(1)), format(text.substr(found.get_end()))]
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
