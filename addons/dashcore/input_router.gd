class_name InputRouter
extends Node
## DashCore: maps touch drags / keys to normalized steering actions.
## One-thumb relative drag: the finger-down point becomes the neutral anchor.
## UI controls consume touches first because this listens in _unhandled_input.

signal steer_started
signal steer_ended

var dead_zone_px: float = 3.0
var enabled: bool = true
var active: bool = false
var touched_this_run: bool = false

var _index: int = -1
var _anchor: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_key_action("steer_left", [KEY_A, KEY_LEFT])
	_add_key_action("steer_right", [KEY_D, KEY_RIGHT])
	_add_key_action("steer_up", [KEY_W, KEY_UP])
	_add_key_action("steer_down", [KEY_S, KEY_DOWN])
	_add_key_action("pause_game", [KEY_ESCAPE, KEY_P])
	_add_key_action("launch", [KEY_SPACE, KEY_ENTER])


func _add_key_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _index == -1:
			_index = t.index
			_anchor = t.position
			_current = t.position
			active = true
			touched_this_run = true
			steer_started.emit()
		elif not t.pressed and t.index == _index:
			_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _index:
			_current = d.position


## Drag offset from the anchor, normalized by viewport height (resolution independent).
func drag_offset() -> Vector2:
	if not active:
		return Vector2.ZERO
	var delta := _current - _anchor
	if delta.length() < dead_zone_px:
		return Vector2.ZERO
	var h := get_viewport().get_visible_rect().size.y
	return delta / maxf(h, 1.0)


func keyboard_axis() -> Vector2:
	if not enabled:
		return Vector2.ZERO
	return Input.get_vector("steer_left", "steer_right", "steer_up", "steer_down")


## Clears held touches (focus loss, resume, state changes).
func reset() -> void:
	if active:
		_release()
	_index = -1


func _release() -> void:
	_index = -1
	active = false
	steer_ended.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset()
