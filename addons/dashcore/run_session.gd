class_name RunSession
extends RefCounted
## DashCore: owns run_id, run state, final score and the revive allowance.
## Contains no vehicle physics. Rejects illegal / duplicate transitions
## (e.g. a second crash callback, or an ad callback after results).

signal state_changed(previous: int, current: int)

enum State { MENU, TUTORIAL, COUNTDOWN, RUNNING, PAUSED, CRASHED, REVIVE_PENDING, RESULTS }

const TRANSITIONS := {
	State.MENU: [State.TUTORIAL, State.COUNTDOWN],
	State.TUTORIAL: [State.RUNNING, State.CRASHED, State.PAUSED, State.MENU],
	State.COUNTDOWN: [State.RUNNING, State.PAUSED, State.MENU],
	State.RUNNING: [State.CRASHED, State.PAUSED],
	State.CRASHED: [State.REVIVE_PENDING, State.RESULTS],
	State.REVIVE_PENDING: [State.RUNNING, State.RESULTS],
	State.RESULTS: [State.MENU, State.COUNTDOWN, State.TUTORIAL],
}

var state: int = State.MENU
var previous_state: int = State.MENU
var run_id: int = 0
var final_score: int = 0
var revives_left: int = 1


func start_run(tutorial: bool = false) -> bool:
	var target: int = State.TUTORIAL if tutorial else State.COUNTDOWN
	if not can_transition(target):
		return false
	run_id += 1
	final_score = 0
	revives_left = 1
	return transition(target)


func can_transition(to: int) -> bool:
	if to == state:
		return false
	if state == State.PAUSED:
		return to == previous_state or to == State.MENU
	if to == State.PAUSED:
		return state in [State.TUTORIAL, State.COUNTDOWN, State.RUNNING]
	var allowed: Array = TRANSITIONS.get(state, [])
	return to in allowed


func transition(to: int) -> bool:
	if not can_transition(to):
		return false
	var prev := state
	if to == State.PAUSED:
		previous_state = state
	state = to
	state_changed.emit(prev, to)
	return true


func pause() -> bool:
	return transition(State.PAUSED)


func resume() -> bool:
	if state != State.PAUSED:
		return false
	return transition(previous_state)


## Returns false for duplicate crash callbacks.
func crash(score_value: int) -> bool:
	if state != State.RUNNING and state != State.TUTORIAL:
		return false
	final_score = score_value
	return transition(State.CRASHED)


func is_live() -> bool:
	return state == State.RUNNING or state == State.TUTORIAL


static func state_name(s: int) -> String:
	return State.keys()[s]
