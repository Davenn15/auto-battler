class_name Shard
extends RefCounted
## The eight kinds of Shard. Two Shards combine into a Keepsake. Shards have no data of
## their own beyond these tables, so this is just constants.

enum Kind { MIGHT, MIGHT_WARD, CELERITY, CELERITY_WARD, INSIGHT, INSIGHT_WARD, HEALTH, WRACK }

const NAMES := {
	Kind.MIGHT: "Might", Kind.MIGHT_WARD: "Might Ward",
	Kind.CELERITY: "Celerity", Kind.CELERITY_WARD: "Celerity Ward",
	Kind.INSIGHT: "Insight", Kind.INSIGHT_WARD: "Insight Ward",
	Kind.HEALTH: "Health", Kind.WRACK: "Wrack",
}

## Each Shard's colour, from the keepsake sheet. Keepsake icons are half one, half the other.
const COLORS := {
	Kind.MIGHT: Color(0.65, 0.11, 0.0),
	Kind.MIGHT_WARD: Color(0.65, 0.30, 0.47),
	Kind.CELERITY: Color(0.95, 0.76, 0.20),
	Kind.CELERITY_WARD: Color(0.90, 0.57, 0.22),
	Kind.INSIGHT: Color(0.24, 0.47, 0.85),
	Kind.INSIGHT_WARD: Color(0.27, 0.51, 0.56),
	Kind.HEALTH: Color(0.42, 0.66, 0.31),
	Kind.WRACK: Color(0.40, 0.31, 0.65),
}

## Reserve each Shard is worth. A Keepsake is worth both of its Shards.
const RESERVE_VALUE := 3
