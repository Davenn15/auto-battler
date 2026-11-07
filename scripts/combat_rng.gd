class_name CombatRng
extends RefCounted
## The one source of chance for everything that affects a fight's outcome (dodges, wracks,
## random targets). It's seeded when a battle starts, so two computers given the same
## armies and the same seed play out exactly the same fight. Purely visual randomness
## (text jitter, effects) should keep using the global randf() so it can't shift the rolls.

static var _rng := RandomNumberGenerator.new()


static func start(seed_value: int) -> void:
	_rng.seed = seed_value


static func randf() -> float:
	return _rng.randf()


static func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


static func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## A random element of `options`, or null if it's empty.
static func pick(options: Array):
	if options.is_empty():
		return null
	return options[_rng.randi_range(0, options.size() - 1)]
