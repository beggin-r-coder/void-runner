class_name NodePool
extends RefCounted
## DashCore: bounded acquire / reset / release pool keyed by type.
## The game owns what a pooled node *means*; the pool only recycles it.
## Pooled nodes stay parented; `on_acquire()` / `on_release()` toggle them.

var _free: Dictionary = {}       # key -> Array[Node]
var _factories: Dictionary = {}  # key -> Callable
var _parent: Node
var active_count: int = 0
var created_count: int = 0
var _active_by_key: Dictionary = {}
var _peak_by_key: Dictionary = {}
var _created_by_key: Dictionary = {}


func _init(parent: Node = null) -> void:
	_parent = parent


func register(key: StringName, factory: Callable, prewarm: int = 0) -> void:
	_factories[key] = factory
	if not _free.has(key):
		_free[key] = []
	for i in prewarm:
		var n := _create(key)
		_park(n)
		_free[key].append(n)


func acquire(key: StringName) -> Node:
	var list: Array = _free[key]
	var n: Node
	if list.is_empty():
		n = _create(key)
	else:
		n = list.pop_back()
	active_count += 1
	_active_by_key[key] = int(_active_by_key.get(key, 0)) + 1
	_peak_by_key[key] = maxi(int(_peak_by_key.get(key, 0)), int(_active_by_key[key]))
	n.set_meta("pool_active", true)
	if n.has_method("on_acquire"):
		n.on_acquire()
	return n


func release(n: Node) -> void:
	if not n.get_meta("pool_active", false):
		return  # double release guard
	n.set_meta("pool_active", false)
	active_count -= 1
	var k: StringName = n.get_meta("pool_key")
	_active_by_key[k] = int(_active_by_key.get(k, 0)) - 1
	_park(n)
	_free[n.get_meta("pool_key")].append(n)


## True when every created node is accounted for by peak concurrent demand
## (i.e. nothing leaked: created never exceeds max(prewarm, peak active)).
func leak_free(prewarm: Dictionary = {}) -> bool:
	for k in _created_by_key:
		if int(_created_by_key[k]) > maxi(int(_peak_by_key.get(k, 0)), int(prewarm.get(k, 0))):
			return false
	return true


func stats() -> String:
	var parts: PackedStringArray = []
	for k in _created_by_key:
		parts.append("%s %d/%d" % [k, int(_created_by_key[k]), int(_peak_by_key.get(k, 0))])
	return ", ".join(parts)


func free_count(key: StringName) -> int:
	return (_free.get(key, []) as Array).size()


func total_free() -> int:
	var c := 0
	for k in _free:
		c += (_free[k] as Array).size()
	return c


func _create(key: StringName) -> Node:
	var n: Node = (_factories[key] as Callable).call()
	n.set_meta("pool_key", key)
	n.set_meta("pool_active", false)
	created_count += 1
	_created_by_key[key] = int(_created_by_key.get(key, 0)) + 1
	if _parent != null and n.get_parent() == null:
		_parent.add_child(n)
	return n


func _park(n: Node) -> void:
	if n.has_method("on_release"):
		n.on_release()
	elif n is Node3D:
		(n as Node3D).visible = false
