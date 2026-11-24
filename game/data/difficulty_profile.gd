class_name DifficultyProfile
extends Resource
## Difficulty raises one variable at a time: speed, then pattern complexity,
## then hazard density. Pressure waves are followed by recovery space.

@export var band_distances: PackedFloat32Array = PackedFloat32Array([0.0, 600.0, 1600.0, 3000.0])
@export var density_by_band: PackedFloat32Array = PackedFloat32Array([0.55, 0.75, 0.95, 1.15])
@export var pressure_seconds: float = 40.0
@export var theme_length: float = 2000.0
@export var theme_count: int = 3


func band_for(distance: float) -> int:
	var band := 0
	for i in band_distances.size():
		if distance >= band_distances[i]:
			band = i
	return band


func density_for(band: int) -> float:
	return density_by_band[clampi(band, 0, density_by_band.size() - 1)]


func theme_for(distance: float) -> int:
	return int(floor(maxf(distance, 0.0) / theme_length)) % theme_count
