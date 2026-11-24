class_name ChunkPlan
extends RefCounted
## A certified, ready-to-spawn corridor chunk.

var index: int = 0
var definition: ChunkDefinition
var theme: int = 0
var band: int = 0
var speed: float = 35.0
var z_start: float = 0.0        # world z of the entry plane (current origin frame)
var length: float = 100.0
var start_distance: float = 0.0 # accumulated route distance at entry
var obstacles: Array = []       # Array[ObstacleSpec], chunk-local
var safe_path: PackedVector3Array = PackedVector3Array()  # chunk-local certified route
var pickups: PackedVector3Array = PackedVector3Array()    # chunk-local energy orbs
var exit_mask: PackedByteArray = PackedByteArray()
var attempts: int = 1
var fell_back: bool = false
var root: Node3D                # active visual root while spawned
var pickup_nodes: Array = []


func z_end() -> float:
	return z_start - length


func uid_for(spec: ObstacleSpec) -> int:
	return index * 256 + spec.group_id
