class_name OnboardingConfig
extends Resource
## Pacing for the first ten minutes: when each system appears and how tips are spaced.
## Single file: content/config/onboarding.tres. Tip wording lives in core/onboarding.gd.

## The Rebirth pads, Rebirths row and gate panel appear once Multiplier reaches this.
@export var rebirth_reveal_mult: float = 200.0
## The streak tip appears after this many presses.
@export var streak_tip_presses: int = 12
## The momentum tip appears after this many seconds of play, once the player has pressed a pad.
@export var walk_tip_seconds: float = 40.0
## Seconds into the game before the welcome tip shows.
@export var first_tip_delay: float = 1.0
## Minimum seconds between two tips (urgent tips ignore this).
@export var tip_gap_seconds: float = 15.0
## A tip card closes by itself after this many seconds.
@export var tip_lifetime: float = 20.0
## An urgent tip (a drop, a critter, a new button) waits at least this long after the last tip before it replaces it.
@export var urgent_gap_seconds: float = 6.0
