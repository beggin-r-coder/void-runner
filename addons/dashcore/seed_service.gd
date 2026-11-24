class_name SeedService
extends RefCounted
## DashCore: one base seed fans out into independent RNG streams so that a
## cosmetic change never alters gameplay (route / hazard layouts).

const STREAMS: Array[String] = ["route", "hazard", "pickup", "cosmetic"]

var base_seed: int = 0
var generator_version: int = 1
var _streams: Dictionary = {}


func _init(seed_value: int = 0, version: int = 1) -> void:
	reset(seed_value, version)


func reset(seed_value: int, version: int = -1) -> void:
	base_seed = seed_value
	if version >= 0:
		generator_version = version
	_streams.clear()
	for stream_name in STREAMS:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%d:%s" % [seed_value, generator_version, stream_name])
		_streams[stream_name] = rng


func stream(stream_name: String) -> RandomNumberGenerator:
	return _streams[stream_name]


static func fresh_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & 0x7fffffff
