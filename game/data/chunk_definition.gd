class_name ChunkDefinition
extends Resource
## One authored corridor module. Its generator places bounded-random
## obstacles; the CorridorDirector certifies a reachable path before use.

@export var id: StringName = &"open"
@export var length: float = 100.0
@export var weight: float = 1.0
@export var min_band: int = 0
@export var is_recovery: bool = false
@export_multiline var notes: String = ""


static func make(p_id: StringName, p_length: float, p_weight: float, p_min_band: int, p_recovery: bool = false) -> ChunkDefinition:
	var d := ChunkDefinition.new()
	d.id = p_id
	d.length = p_length
	d.weight = p_weight
	d.min_band = p_min_band
	d.is_recovery = p_recovery
	return d
