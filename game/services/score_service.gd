class_name ScoreService
extends RefCounted
## Scoring contract:
##   score = floor(distance_m) + sum over near misses of (40 x combo at that pass)
## Combo rises to 5 per valid close pass, expires after 4 s without one and
## resets on revive. Only this service turns gameplay events into points.

var cfg: HandlingConfig
var distance: float = 0.0
var combo: int = 0
var combo_timer: float = 0.0
var near_miss_count: int = 0
var near_miss_points: int = 0
var orbs: int = 0


func _init(p_cfg: HandlingConfig) -> void:
	cfg = p_cfg


func reset() -> void:
	distance = 0.0
	combo = 0
	combo_timer = 0.0
	near_miss_count = 0
	near_miss_points = 0
	orbs = 0


func tick(delta: float) -> void:
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			combo_timer = 0.0


## Returns the points awarded for this near miss.
func register_near_miss() -> int:
	combo = mini(combo + 1, cfg.combo_max)
	combo_timer = cfg.combo_timeout
	near_miss_count += 1
	var pts := cfg.near_miss_points * combo
	near_miss_points += pts
	return pts


func on_revive() -> void:
	combo = 0
	combo_timer = 0.0


func score() -> int:
	return int(floor(distance)) + near_miss_points


func credits_earned() -> int:
	return score() / maxi(cfg.credits_per_score, 1) + orbs
