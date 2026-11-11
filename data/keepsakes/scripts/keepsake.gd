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



var _icon: ImageTexture   # made the first time it's asked for
## Width in pixels (of the 32-pixel icon) of the white border round keepsake icons.
const ICON_BORDER_WIDTH := 3


func get_reserve_value() -> int:
	return Shard.RESERVE_VALUE * (1 if is_shard else 2)


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
func get_icon(size: int = 32) -> Texture2D:
	if _icon == null:
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var right: Shard.Kind = first_shard if is_shard else second_shard
		image.fill_rect(Rect2i(0, 0, floori(size / 2.0), size), Shard.COLORS[first_shard])
		image.fill_rect(Rect2i(floori(size / 2.0), 0, size - floori(size / 2.0), size), Shard.COLORS[right])
		if not is_shard:
			var border := ICON_BORDER_WIDTH
			image.fill_rect(Rect2i(0, 0, size, border), Color.WHITE)
			image.fill_rect(Rect2i(0, size - border, size, border), Color.WHITE)
			image.fill_rect(Rect2i(0, 0, border, size), Color.WHITE)
			image.fill_rect(Rect2i(size - border, 0, border, size), Color.WHITE)
		_icon = ImageTexture.create_from_image(image)
	return _icon
