extends SceneTree
## Offline audio check: we cannot listen, so measure. Every procedural sound must
## be finite, must not clip, must not be silent, and loops must not click at the seam.
## Run: godot --headless --path . --script res://tests/audio_check.gd

func _initialize() -> void:
	await process_frame
	var sfx: Node = root.get_node("Sfx")
	var fails := 0
	print("== audio check (peak / RMS in dBFS) ==")
	var names: Array = sfx.raw.keys()
	names.sort()
	for n in names:
		var s: PackedFloat32Array = sfx.raw[n]
		var peak := 0.0
		var sum := 0.0
		var finite := true
		var clipped := 0
		for v in s:
			if is_nan(v) or is_inf(v):
				finite = false
				continue
			peak = maxf(peak, absf(v))
			sum += v * v
			if absf(v) >= 1.0:
				clipped += 1
		var rms := sqrt(sum / maxf(s.size(), 1))
		var looped: bool = n in ["engine", "wind", "ambient"]
		# a loop seam must not jump more than the signal's own 99.9th-percentile step
		var seam := absf(s[0] - s[s.size() - 1]) if looped else 0.0
		var steps := PackedFloat32Array()
		if looped:
			for i in range(1, s.size()):
				steps.append(absf(s[i] - s[i - 1]))
			steps.sort()
		var p99 := steps[int(steps.size() * 0.999)] if looped else 1.0
		var ok := finite and clipped == 0 and linear_to_db(rms) > -40.0 and seam <= p99
		if not ok:
			fails += 1
		print("  %s %-7s %5.2fs  peak %6.1f  rms %6.1f  clipped %d%s" % ["PASS" if ok else "FAIL", n, s.size() / 22050.0, linear_to_db(maxf(peak, 1e-9)), linear_to_db(maxf(rms, 1e-9)), clipped, ("  loop seam %.3f (p99.9 step %.3f)" % [seam, p99]) if looped else ""])
	var lim_ok := AudioServer.get_bus_effect_count(0) > 0 and AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter
	print("  %s master bus hard limiter present" % ("PASS" if lim_ok else "FAIL"))
	if not lim_ok:
		fails += 1
	print("== audio check: %s ==" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
