class_name RouteFollower
extends RefCounted
## Autopilot for attract mode / automated captures: tracks the director's
## certified route with velocity feed-forward. Uses the same acceleration-
## limited FlightController, so a surviving bot is evidence the route is
## controller-feasible.

var director: CorridorDirector
var lead: float = 0.01
var ff_window: float = 0.08
## Tracking gain used instead of HandlingConfig.steer_response (physical
## limits - max speed and acceleration - are unchanged).
var gain: float = 22.0


func _init(p_director: CorridorDirector) -> void:
	director = p_director


## Returns [target: Vector2, feed_forward_velocity: Vector2]
func sample(z: float, speed: float) -> Array:
	var s := maxf(speed, 10.0)
	var a := director.safe_target(z - s * lead)
	var b := director.safe_target(z - s * (lead + ff_window))
	return [a, (b - a) / ff_window]
