class_name AscensionFamily
extends Resource
## Every tier of one Ascension in a single file, so they can all be edited from one
## Inspector: e.g. Neutral Celerity I-IV. Each entry in `versions` is a full Ascension
## (give it its own tier, stats, description...). Put the file in a pool folder like any
## Ascension.
##
## The versions are one family: once a player owns any of them, the others are never
## offered. A version with no name of its own is called "<family name> <tier numeral>".

@export var family_name: String = ""
## One Ascension per tier, each with its own Tier set.
@export var versions: Array[Ascension] = []
