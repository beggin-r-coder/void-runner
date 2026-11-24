class_name PooledVisual
extends Node3D
## Lightweight pooled visual (energy orbs).

var spin_node: Node3D


func on_acquire() -> void:
	visible = true
	scale = Vector3.ONE


func on_release() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible and spin_node:
		spin_node.rotate_y(delta * 3.0)
		spin_node.rotate_x(delta * 1.3)
