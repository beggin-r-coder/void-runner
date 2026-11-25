extends Node
## DashCore audio: procedurally synthesized placeholder sound set so the
## prototype has layered engine/speed audio and distinct warning cues
## without third-party assets. Swap buffers for licensed audio later.

const RATE := 22050
const LOOP_FADE := 1200

var _buffers: Dictionary = {}
## Raw float samples per sound, kept for offline checks (tests/audio_check.gd).
var raw: Dictionary = {}
var _ambient: AudioStreamPlayer
var _ambient_target_db := -80.0
var _engine: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _one_shots: Array[AudioStreamPlayer] = []
var _next_shot := 0
var volume: float = 0.9
var _engine_target_db := -80.0
var _wind_target_db := -80.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Master safety limiter: stacked one-shots (crash boom on a full-speed engine)
	# must never clip the output.
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, lim)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	_buffers["engine"] = _wav(_keep("engine", _fold_loop(_synth_engine(rng), LOOP_FADE)), true)
	_buffers["wind"] = _wav(_keep("wind", _fold_loop(_synth_wind(rng), LOOP_FADE)), true)
	_buffers["whoosh"] = _wav(_keep("whoosh", _synth_whoosh(rng)), false)
	_buffers["boom"] = _wav(_keep("boom", _normalize(_synth_boom(rng), 0.89)), false)
	_buffers["chime"] = _wav(_keep("chime", _synth_chime()), false)
	_buffers["beep"] = _wav(_keep("beep", _synth_tone(660.0, 0.12, 0.5)), false)
	_buffers["go"] = _wav(_keep("go", _synth_tone(990.0, 0.3, 0.5)), false)
	_buffers["click"] = _wav(_keep("click", _synth_tone(1400.0, 0.04, 0.35)), false)
	_buffers["warn"] = _wav(_keep("warn", _synth_warn()), false)
	_buffers["ambient"] = _wav(_keep("ambient", _fold_loop(_synth_ambient(), LOOP_FADE)), true)
	_ambient = _player("ambient")
	_engine = _player("engine")
	_wind = _player("wind")
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_one_shots.append(p)


func _player(buf: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _buffers[buf]
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _process(delta: float) -> void:
	var k := 1.0 - exp(-6.0 * delta)
	_engine.volume_db = lerpf(_engine.volume_db, _engine_target_db, k)
	_wind.volume_db = lerpf(_wind.volume_db, _wind_target_db, k)
	_ambient.volume_db = lerpf(_ambient.volume_db, _ambient_target_db, 1.0 - exp(-1.5 * delta))


## speed_t: 0..1 normalized speed; active: whether the engine should be audible.
func set_flight(speed_t: float, active: bool) -> void:
	var vol := linear_to_db(maxf(volume, 0.0001))
	_engine_target_db = (-14.0 + 6.0 * speed_t + vol) if active else -60.0
	_wind_target_db = (-26.0 + 14.0 * speed_t + vol) if active else -60.0
	_engine.pitch_scale = 0.8 + 0.7 * speed_t
	_wind.pitch_scale = 0.8 + 0.5 * speed_t


func play(name: String, pitch: float = 1.0, gain_db: float = 0.0) -> void:
	if not _buffers.has(name):
		return
	var p := _one_shots[_next_shot]
	_next_shot = (_next_shot + 1) % _one_shots.size()
	p.stream = _buffers[name]
	p.pitch_scale = pitch
	p.volume_db = gain_db + linear_to_db(maxf(volume, 0.0001))
	p.play()


# --- synthesis -------------------------------------------------------------

## Seamless loop: the generator renders LOOP_FADE extra samples past the loop
## length; that tail is cross-faded into the head, so sample[n-1] -> sample[0]
## continues the original signal with no discontinuity.
func _fold_loop(src: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := src.size() - fade
	var out := src.slice(0, n)
	for i in fade:
		var f := float(i) / fade
		out[i] = src[i] * f + src[n + i] * (1.0 - f)
	return out


func _normalize(src: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for v in src:
		m = maxf(m, absf(v))
	if m <= peak or m == 0.0:
		return src
	var out := src.duplicate()
	for i in out.size():
		out[i] *= peak / m
	return out


func _keep(name: String, samples: PackedFloat32Array) -> PackedFloat32Array:
	raw[name] = samples
	return samples


## Quiet space-pad bed for menu / results so those screens are never dead silent.
func set_ambient(on: bool) -> void:
	_ambient_target_db = (-20.0 + linear_to_db(maxf(volume, 0.0001))) if on else -60.0


## Instantly silences the flight layers (crash), instead of the usual fade.
func cut_flight() -> void:
	_engine_target_db = -60.0
	_wind_target_db = -60.0
	_engine.volume_db = -30.0
	_wind.volume_db = -30.0


func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _synth_engine(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := RATE + LOOP_FADE  # 1 s loop + fold tail; partials are integer Hz
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		s += 0.35 * sin(TAU * 55.0 * t)
		s += 0.25 * sin(TAU * 110.0 * t + 0.4)
		s += 0.12 * sin(TAU * 165.0 * t + 1.1)
		s += 0.08 * (fposmod(t * 220.0, 1.0) * 2.0 - 1.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		s += lp * 0.5
		s *= 0.85 + 0.15 * sin(TAU * 6.0 * t)
		out[i] = s * 0.6
	return out


func _synth_wind(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := RATE + LOOP_FADE
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var w := rng.randf_range(-1.0, 1.0)
		a += (w - a) * 0.25
		b += (a - b) * 0.25
		out[i] = (a - b) * 1.6
	return out


func _synth_ambient() -> PackedFloat32Array:
	# 2 s loop: 55 / 82.5 / 110 / 165 Hz all complete whole cycles, slow 0.5 Hz swell
	var n := RATE * 2 + LOOP_FADE
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var swell := 0.75 + 0.25 * sin(TAU * 0.5 * t)
		var s := sin(TAU * 55.0 * t) * 0.4 + sin(TAU * 82.5 * t) * 0.25 + sin(TAU * 110.0 * t + 0.7) * 0.2 + sin(TAU * 165.0 * t + 1.9) * 0.08
		out[i] = s * swell * 0.5
	return out


func _synth_whoosh(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 0.45)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var cutoff := lerpf(0.05, 0.6, sin(t * PI))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * cutoff
		var env := sin(t * PI) * (1.0 - t * 0.4)
		out[i] = lp * env * 0.9
	return out


func _synth_boom(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(RATE * 1.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.5, 0.03, minf(t * 2.0, 1.0))
		var thump := sin(TAU * lerpf(90.0, 30.0, minf(t * 3.0, 1.0)) * t) * exp(-t * 5.0)
		out[i] = (lp * 1.2 * exp(-t * 2.6) + thump * 0.9) * 0.9
	return out


func _synth_chime() -> PackedFloat32Array:
	var n := int(RATE * 0.35)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 9.0)
		out[i] = (sin(TAU * 1320.0 * t) * 0.5 + sin(TAU * 1980.0 * t) * 0.3) * env * 0.7
	return out


func _synth_tone(freq: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t * 200.0, 1.0) * exp(-t * 6.0 / dur)
		out[i] = sin(TAU * freq * t) * env * amp
	return out


func _synth_warn() -> PackedFloat32Array:
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var gate := 1.0 if fposmod(t, 0.125) < 0.07 else 0.0
		out[i] = (fposmod(t * 880.0, 1.0) * 2.0 - 1.0) * gate * 0.35
	return out
