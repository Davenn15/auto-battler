class_name BeamRicochetEffect
extends Passive
## An Ascension effect: the unit's Beams (see Beam) ricochet to more targets, each extra
## ricochet at a share of the Beam's strength.

## Extra targets each Beam ricochets to.
@export var extra_ricochets: int = 1
## How strong each extra ricochet is: 0.5 = half the Beam's damage or shielding.
@export_range(0.0, 1.0, 0.05) var ricochet_share: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BeamRicochetStatus.new(extra_ricochets, ricochet_share))


class BeamRicochetStatus extends Status:
	var extra: int
	var share: float

	func _init(p_extra: int, p_share: float) -> void:
		extra = p_extra
		share = p_share

	func modify_beam(_unit: BattleUnit, settings: Beam.Settings) -> void:
		settings.extra_ricochets += extra
		settings.ricochet_share = share
