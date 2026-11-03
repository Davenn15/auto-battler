class_name BagThrownStatus
extends Status
## Marks that Sumpton has thrown his bag this battle, so a new bag comes back hurt
## instead of at full health. It does nothing else.


## Statuses a Gambit creates block charge until they end. This one lasts all battle,
## so it mustn't.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false
