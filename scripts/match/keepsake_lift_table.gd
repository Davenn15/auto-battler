class_name KeepsakeLiftTable
extends Resource
## What the balance sims learned about keepsakes: for each unit and keepsake, how much more
## often the unit's team won when the unit carried it, compared with the same unit carrying
## the same number of other items at a similar ARV. Built by tools/keepsake_table.gd from a
## sim's _units.csv; read by KeepsakeSense.

## Unit name (as the sim writes it, e.g. "Batr.ee") ->
## {keepsake name -> [lift, battles, reliability, average]}.
##   average: how much more often the unit's team won with it, in win rate (0.05 = 5 points).
##   reliability: 0-1, how much of that average is real rather than chance from few battles.
##   lift: average x reliability, the best single guess.
@export var lift: Dictionary = {}
## How much pairs really differ (with the chance part taken out), in win rate. KeepsakeSense
## uses it to put lift on the same scale as its own data-based score.
@export var spread: float = 0.05
## Where the numbers came from, for reading the file.
@export var source: String = ""


func get_lift(unit_name: String, keepsake_name: String) -> Array:
	var row: Dictionary = lift.get(unit_name, {})
	return row.get(keepsake_name, [0.0, 0, 0.0, 0.0])
