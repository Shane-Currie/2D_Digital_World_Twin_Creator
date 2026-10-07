extends RefCounted

## Stage-one gameplay approximations, in kilograms and SI units. These are
## deliberately separate from driving controls and from future health/damage.
const PLAYER_MASS_KG := 1600.0
const PERSON_MASS_KG := 75.0
const ROBOT_MASS_KG := 140.0
const VEHICLE_MASSES_KG := {"sedan": 1450.0, "wagon": 1600.0, "ute": 1800.0}
const RESTITUTION := 0.08
const MIN_CLOSING_SPEED_MPS := 0.05
const MAX_MOVEMENT_STEP_PIXELS := 2.0
const RECOVERY_DELAY_SECONDS := 0.8
const ANGULAR_DECELERATION := 2.2
const MAX_SPIN_RADIANS_PER_SECOND := 6.0


static func mass_for(agent: Dictionary) -> float:
	match str(agent.get("kind", "")):
		"person": return PERSON_MASS_KG
		"robot": return ROBOT_MASS_KG
	return float(VEHICLE_MASSES_KG.get(str(agent.get("vehicle_style", "sedan")), 1450.0))


static func sliding_deceleration(agent: Dictionary) -> float:
	# Sliding, not ordinary walking/driving acceleration: kinetic friction
	# removes momentum over time rather than teleporting the sprite backwards.
	return 5.5 if str(agent.get("kind", "")) == "traffic" else 7.5
