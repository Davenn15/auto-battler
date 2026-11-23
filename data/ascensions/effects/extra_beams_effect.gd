class_name ExtraBeamsEffect
extends Passive
## BEAM.NG's hero Ascension: its attack Beam and its Gambit's Beam (Shield Beam or Focus
## Beam) each get Extra Beams more Beams from it, at Share of their damage or shielding,
## each at another target when there is one (see Beam.Settings.extra_beams).

@export var extra_beams: int = 2
## 0.3 = 30% of the damage or shielding.
@export var share: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	var status := FanStatus.new()
	status.effect = self
	unit.add_status(status)


class FanStatus extends Status:
	var effect: ExtraBeamsEffect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_beam(_unit: BattleUnit, settings: Beam.Settings) -> void:
		if settings.kind == Beam.Kind.ATTACK or settings.kind == Beam.Kind.SHIELD or settings.kind == Beam.Kind.FOCUS:
			settings.extra_beams += effect.extra_beams
			settings.extra_beam_share = effect.share
