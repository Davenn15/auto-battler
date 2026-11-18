class_name SimMode
extends RefCounted
## The lean battle mode for computer-only simulations (real_sim, match_sim, the AI's test
## battles): when active, battles skip everything that only exists to be looked at
## (health and Charge bars, damage numbers, floating text, effects) so the computer can
## play more of them. It must never change how a fight plays out: tools/sim_bench.gd
## checks that fights end exactly the same with it on and off.

static var active := false


## True when visual-only work can be skipped: in lean mode, or when nothing is drawn.
static func skip_visuals() -> bool:
	return active
