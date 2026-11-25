class_name Keepsake
extends Resource
## Equipment made from two Shards: a block of stats plus, usually, a special effect.
## Like Passives and Gambits, these are shared settings: nothing here changes in battle.

@export var keepsake_name: String = ""
@export var first_shard: Shard.Kind = Shard.Kind.MIGHT
@export var second_shard: Shard.Kind = Shard.Kind.MIGHT

@export_group("Stats")
@export var might: float = 0.0
@export var might_ward: float = 0.0
@export var celerity: float = 0.0
@export var celerity_ward: float = 0.0
@export var insight: float = 0.0
@export var insight_ward: float = 0.0
@export var health: float = 0.0
## 0.2 = +20% wrack chance.
@export var wrack_chance: float = 0.0
## 0.2 = +20% wrack damage.
@export var wrack_damage: float = 0.0
## Share of damage dealt that heals the wearer (0.1 = 10%).
@export var vampirism: float = 0.0

@export_group("Effect")
## The keepsake's special effect, as a Passive that adds its status at battle start.
@export var effect: Passive
@export_multiline var description: String = ""
## True for a single loose Shard (only first_shard counts). It takes a keepsake slot.
@export var is_shard: bool = false

@export_group("Empowering")
## How each Shard kind empowers this Keepsake (Keepsake Empowering): one entry per kind,
## from its own two. A kind with no entry can't empower it.
@export var empowerments: Array[Empowerment] = []

## Stat properties an Empowerment adds to (same names on both).
const STAT_PROPERTIES := ["might", "might_ward", "celerity", "celerity_ward", "insight",
		"insight_ward", "health", "wrack_chance", "wrack_damage", "vampirism"]

## On an empowered copy (made by empowered()): the Shard kind that empowered it, the plain
## Keepsake it was made from, and the Empowerment's extra effects. -1 / null / [] otherwise.
var empowered_with: int = -1
var empowered_from: Keepsake
var extra_effects: Array[Passive] = []
## On an empowered copy: the Empowerment's own text (shown under the Keepsake's).
var empowerment_text: String = ""



var _icon: ImageTexture   # made the first time it's asked for
## Width in pixels (of the 32-pixel icon) of the white border round keepsake icons.
const ICON_BORDER_WIDTH := 3
## Empowered Keepsakes' border (placeholder look).
const EMPOWERED_BORDER := Color(1.0, 0.8, 0.25)


## True if `other` is the same completed Keepsake (by file, or by name for ones made in
## code). Shards never count: a unit may carry two of the same Shard.
func same_keepsake(other: Keepsake) -> bool:
	if other == null or is_shard or other.is_shard:
		return false
	var mine := base_keepsake()   # an empowered copy is still the same Keepsake
	var theirs := other.base_keepsake()
	if theirs == mine:
		return true
	if mine.resource_path != "" and theirs.resource_path != "":
		return mine.resource_path == theirs.resource_path
	return mine.get_display_name() == theirs.get_display_name()


# ---------- Keepsake Empowering ----------

func is_empowered() -> bool:
	return empowered_with >= 0


## The plain Keepsake: itself, or the one an empowered copy was made from.
func base_keepsake() -> Keepsake:
	return empowered_from if empowered_from != null else self


## How a Shard of `kind` would empower this Keepsake, or null if it can't: Shards, already
## empowered Keepsakes and kinds that aren't one of its two (or have no entry) can't.
func empowerment_for(kind: int) -> Empowerment:
	if is_shard or is_empowered() or (kind != first_shard and kind != second_shard):
		return null
	for empowerment in empowerments:
		if empowerment != null and empowerment.shard == kind:
			return empowerment
	return null


## A new, empowered copy of this Keepsake (the Shard's stats, effect changes and text
## added), or null if a Shard of `kind` can't empower it. The shared file never changes.
func empowered(kind: int) -> Keepsake:
	var empowerment := empowerment_for(kind)
	if empowerment == null:
		return null
	var copy := duplicate() as Keepsake
	copy.empowered_with = kind
	copy.empowered_from = self
	var shard := Keepsake.shard_of(kind)   # the Shard's own stats come with it
	for property in STAT_PROPERTIES:
		var added := float(empowerment.get(property))
		if shard != null:
			added += float(shard.get(property))
		copy.set(property, float(get(property)) + added)
	var new_effect: Passive = empowerment.replace_effect if empowerment.replace_effect != null else effect
	if new_effect != null and not (empowerment.effect_bonuses.is_empty() and empowerment.effect_overrides.is_empty()):
		new_effect = new_effect.duplicate() as Passive
		for property in empowerment.effect_bonuses:
			if property in new_effect:
				var current = new_effect.get(property)
				new_effect.set(property, current + type_convert(empowerment.effect_bonuses[property], typeof(current)))
			else:
				push_warning("%s: Empowerment changes unknown effect property '%s'." % [get_display_name(), property])
		for property in empowerment.effect_overrides:
			if property in new_effect:
				new_effect.set(property, type_convert(empowerment.effect_overrides[property], typeof(new_effect.get(property))))
			else:
				push_warning("%s: Empowerment sets unknown effect property '%s'." % [get_display_name(), property])
	copy.effect = new_effect
	copy.extra_effects = empowerment.extra_effects.duplicate()
	copy.empowerment_text = empowerment.description
	return copy


## The loose Shard of `kind` (its stats), or null.
static func shard_of(kind: int) -> Keepsake:
	var path := "res://data/keepsakes/shards/%s.tres" % String(Shard.NAMES.get(kind, "")).to_lower().replace(" ", "_")
	return load(path) as Keepsake if ResourceLoader.exists(path) else null


## Where this Keepsake's description placeholders get their numbers: its effect (named
## "effect"), its extra effects ("extra", "extra2", ...), then the Keepsake itself.
func description_context() -> DescriptionContext:
	var ctx := DescriptionContext.new()
	if effect != null:
		ctx.sources.append(effect)
		ctx.named["effect"] = effect
	for i in extra_effects.size():
		ctx.sources.append(extra_effects[i])
		ctx.named["extra" if i == 0 else "extra%d" % (i + 1)] = extra_effects[i]
	ctx.sources.append(self)
	return ctx


## A text reference that survives saving and sending (online play, the computer's test
## battles): the file path, plus "#kind" if empowered.
func to_ref() -> String:
	var base := base_keepsake()
	return base.resource_path + ("#%d" % empowered_with if is_empowered() else "")


static func from_ref(ref: String) -> Keepsake:
	var parts := ref.split("#")
	if parts[0] == "" or not ResourceLoader.exists(parts[0]):
		push_warning("Keepsake reference '%s' doesn't point at a Keepsake file." % ref)
		return null
	var keepsake := load(parts[0]) as Keepsake
	if keepsake != null and parts.size() > 1:
		var copy := keepsake.empowered(int(parts[1]))
		if copy != null:
			return copy
	return keepsake


## The universal Keepsake rule: a unit can't carry two of the same completed Keepsake.
## True if `item` may join `items` (a unit's Keepsakes) under that rule; it says nothing
## about free slots.
static func allowed_with(item: Keepsake, items: Array) -> bool:
	if item == null or item.is_shard:
		return true
	for other in items:
		if other != null and item.same_keepsake(other):
			return false
	return true


func get_reserve_value() -> int:
	return Shard.RESERVE_VALUE * (1 if is_shard else (3 if is_empowered() else 2))


func get_display_name() -> String:
	if keepsake_name != "":
		return keepsake_name
	if is_shard:
		return "%s Shard" % Shard.NAMES[first_shard]
	return "%s + %s" % [Shard.NAMES[first_shard], Shard.NAMES[second_shard]]


## The stats this keepsake adds, as {Stats.Stat: amount}.
func get_stat_bonuses() -> Dictionary:
	return {
		Stats.Stat.MIGHT: might, Stats.Stat.MIGHT_WARD: might_ward,
		Stats.Stat.CELERITY: celerity, Stats.Stat.CELERITY_WARD: celerity_ward,
		Stats.Stat.INSIGHT: insight, Stats.Stat.INSIGHT_WARD: insight_ward,
		Stats.Stat.WRACK_CHANCE: wrack_chance, Stats.Stat.WRACK_DAMAGE: wrack_damage,
		Stats.Stat.VAMPIRISM: vampirism,
	}


## Placeholder art: a square, left half the first Shard's colour, right half the second's.
## Keepsakes (combined items) get a thin white border so they stand out from Shards.
## A resource path for the icon, for BBCode [img] tags (descriptions mark a Keepsake's
## boosts with it). The icon is made in code, so it's given a path in the resource cache.
func icon_path() -> String:
	var icon := get_icon()
	if icon.resource_path == "":
		icon.take_over_path("res://__generated/keepsake_icon_%d.tres" % icon.get_instance_id())
	return icon.resource_path


func get_icon(size: int = 32) -> Texture2D:
	if _icon == null:
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var right: Shard.Kind = first_shard if is_shard else second_shard
		image.fill_rect(Rect2i(0, 0, floori(size / 2.0), size), Shard.COLORS[first_shard])
		image.fill_rect(Rect2i(floori(size / 2.0), 0, size - floori(size / 2.0), size), Shard.COLORS[right])
		if not is_shard:
			# Empowered: a gold border and a pip in the empowering Shard's colour (placeholder).
			var edge := EMPOWERED_BORDER if is_empowered() else Color.WHITE
			var border := ICON_BORDER_WIDTH
			image.fill_rect(Rect2i(0, 0, size, border), edge)
			image.fill_rect(Rect2i(0, size - border, size, border), edge)
			image.fill_rect(Rect2i(0, 0, border, size), edge)
			image.fill_rect(Rect2i(size - border, 0, border, size), edge)
			if is_empowered():
				var pip := floori(size * 0.38)
				var box := Rect2i(size - border - pip, border, pip, pip)
				image.fill_rect(box, edge)
				image.fill_rect(box.grow(-1), Shard.COLORS[empowered_with])
		_icon = ImageTexture.create_from_image(image)
	return _icon
