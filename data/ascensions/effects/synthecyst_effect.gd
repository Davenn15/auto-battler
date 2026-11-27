class_name SynthecystEffect
extends Passive
## An Ascension effect (Obelisk, Synthecyst): the army's summons become one Synthecyst. Does
## nothing at battle start; BattleManager.add_summon hands every summon to Synthecyst.intercept.

## Share of each summon's max health it absorbs (0.75 = 75%).
@export var absorb_share: float = 0.75
## Share of each summon's attributes and Wards it absorbs (0.25 = 25%).
@export var stat_share: float = 0.25
## When it Revives: the absorbed health plus this share of its own base max health.
@export var revive_base_share: float = 0.15
