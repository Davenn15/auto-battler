class_name Empowerment
extends Resource
## Keepsake Empowering: what one Shard adds to a finished Keepsake when the two are put
## together on the ritual table. The Shard's own stats always come with it (see
## Keepsake.empowered); everything here is on top of those. Each Keepsake lists its Empowerments (see
## Keepsake.empowerments), one per Shard kind that can empower it; only the Keepsake's own
## two kinds count. Everything here goes on top of the Keepsake: leave what isn't needed
## at zero or empty.

## The Shard that gives this Empowerment.
@export var shard: Shard.Kind = Shard.Kind.MIGHT
## What it adds, shown under the Keepsake's own text as "Empowered (Kind): ...".
@export_multiline var description: String = ""

@export_group("Extra stats")
@export var might: float = 0.0
@export var might_ward: float = 0.0
@export var celerity: float = 0.0
@export var celerity_ward: float = 0.0
@export var insight: float = 0.0
@export var insight_ward: float = 0.0
@export var health: float = 0.0
## 0.1 = +10% wrack chance.
@export var wrack_chance: float = 0.0
## 0.1 = +10% wrack damage.
@export var wrack_damage: float = 0.0
## 0.05 = 5% more of damage dealt heals the wearer.
@export var vampirism: float = 0.0

@export_group("Effect changes")
## Numbers on the Keepsake's effect to raise, as {"property": amount}: {"damage": 20.0}
## adds 20 to the effect's damage.
@export var effect_bonuses: Dictionary = {}
## Effect properties to set outright, as {"property": value}.
@export var effect_overrides: Dictionary = {}
## A different effect to use instead of the Keepsake's own (the changes above then apply
## to this one).
@export var replace_effect: Passive
## More effects the empowered Keepsake runs as well as its own.
@export var extra_effects: Array[Passive] = []
