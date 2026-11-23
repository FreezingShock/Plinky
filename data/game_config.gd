class_name GameConfig
extends Resource
## Global rules and tunables. Single file: content/config/game.tres.

@export var tick_rate: int = 10
@export var max_ticks_per_frame: int = 50
@export var autosave_seconds: float = 30.0
@export var offline_base_cap_hours: float = 2.0
@export var prestige_exponent: float = 0.8
@export var crit_multiplier: float = 5.0
## Rebirth needs this stat at or above rebirth_min_value, and converts it to prestige.
@export var prestige_source_stat: StringName = &"reb"
@export var prestige_stat: StringName = &"prestige"
@export var rebirth_min_value: float = 1.0

## Rebirth payoff grows past this much of the source stat: gain = value * (value / threshold) ^ exponent.
## Set threshold to 0 to turn the bonus off.
@export var prestige_push_threshold: float = 9.0
@export var prestige_push_exponent: float = 0.5
## Rebirth Points: each rebirth pays rp_base, plus rp_growth for every rebirth already done (rounded down).
## Spendable on the Rebirth perks in Upgrades. Separate from Prestige; rebirths still only boost Multiplier gain.
@export var rp_stat: StringName = &"rp"
@export var rp_base: float = 1.0
@export var rp_growth: float = 0.1
## Momentum: walking charges it (pressing nudges it), then it holds a moment and falls. Income gets
## x(1 + momentum * momentum_max_bonus + the kickers of every stage reached). Stages: Idle, then one per threshold.
## Full bar = max_bonus + sum(tier_bonus) = +40%.
@export var momentum_max_bonus: float = 0.28
@export var momentum_tier_thresholds: PackedFloat32Array = PackedFloat32Array([0.2, 0.45, 0.7, 0.995])
@export var momentum_tier_bonus: PackedFloat32Array = PackedFloat32Array([0.01, 0.02, 0.03, 0.06])
@export var momentum_tier_names: PackedStringArray = PackedStringArray(["Idle", "Stride", "Rhythm", "Flow", "Surge"])
@export var momentum_grace: float = 1.2          ## seconds it holds after the last charge before it drains
@export var momentum_surge_hold: float = 4.0     ## the same hold when the bar is full (Surge)
@export var momentum_per_press: float = 0.01     ## charge per pad press (pressing alone settles near Stride)
@export var momentum_per_crit: float = 0.05      ## extra charge on a crit
@export var momentum_per_unit: float = 0.0055    ## charge per texel walked (about 180 texels fills it)
@export var momentum_decay_per_second: float = 0.1
## Press streak tiers (PressStreak, ui/fx/press_popups.gd). Presses closer together than popup_streak_gap seconds chain.
## Score = chain length x (1 + momentum stage x popup_momentum_weight); each threshold reached is one tier:
## Plain, Gold, Ice, Rainbow, Chroma, Galaxy. Pure presentation: tiers never change income.
@export var popup_streak_gap: float = 1.6
@export var popup_tier_thresholds: PackedFloat32Array = PackedFloat32Array([8.0, 20.0, 45.0, 90.0, 180.0])
@export var popup_tier_names: PackedStringArray = PackedStringArray(["Plain", "Gold", "Ice", "Rainbow", "Chroma", "Galaxy"])
@export var popup_momentum_weight: float = 0.35
## A relic pulse hits each neighbour this many seconds after the one before it, so the chain reads as a ripple.
@export var pulse_echo_delay: float = 0.09
## Walker movement (WalkerMotion). Multipliers on the walk speed, so Attribute levels still scale everything.
@export var sprint_mult: float = 1.55            ## Shift held, or Ctrl locked
@export var crouch_mult: float = 0.5             ## C held on the ground
@export var slide_mult_start: float = 2.2        ## C pressed while sprinting: burst, easing down to slide_mult_end
@export var slide_mult_end: float = 0.6
@export var slide_time: float = 0.7              ## seconds
@export var jump_boost_per: float = 0.3          ## speed bonus added by each jump (bunny hops stack)
@export var jump_boost_max: float = 0.6
@export var jump_boost_decay: float = 0.45       ## bonus lost per second
## Pad streak: press a row's buttons in order, each within streak_window seconds of the last.
@export var streak_window: float = 10.0
@export var streak_bonus_seconds: float = 5.0    ## income paid on completing a streak
@export var streak_cooldown: float = 20.0
## Golden critter: appears now and then, click it for critter_income_seconds of income.
@export var critter_min_interval: float = 75.0
@export var critter_max_interval: float = 150.0
@export var critter_lifetime: float = 12.0
@export var critter_income_seconds: float = 30.0
