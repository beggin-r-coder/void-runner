extends Node
## DashCore audio: procedurally synthesized placeholder sound set so the
## prototype has layered engine/speed audio and distinct warning cues
## without third-party assets. Swap buffers for licensed audio later.

const RATE := 22050

var _buffers: Dictionary = {}
var _engine: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _one_shots: Array[AudioStreamPlayer] = []
var _next_shot := 0
var volume: float = 0.9
var _engine_target_db := -80.0
var _wind_target_db := -80.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	_buffers["engine"] = _wav(_synth_engine(rng), true)
	_buffers["wind"] = _wav(_synth_wind(rng), true)
	_buffers["whoosh"] = _wav(_synth_whoosh(rng), false)
	_buffers["boom"] = _wav(_synth_boom(rng), false)
	_buffers["chime"] = _wav(_synth_chime(), false)
	_buffers["beep"] = _wav(_synth_tone(660.0, 0.12, 0.5), false)
	_buffers["go"] = _wav(_synth_tone(990.0, 0.3, 0.5), false)
	_buffers["click"] = _wav(_synth_tone(1400.0, 0.04, 0.35), false)
	_buffers["warn"] = _wav(_synth_warn(), false)
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
	var n := RATE  # 1 s loop; all partials are integer Hz so it loops cleanly
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
	var n := RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var w := rng.randf_range(-1.0, 1.0)
		a += (w - a) * 0.25
		b += (a - b) * 0.25
		out[i] = (a - b) * 1.6
	# crossfade the seam
	var fade := 600
	for i in fade:
		var f := float(i) / fade
		out[i] = out[i] * f + out[n - fade + i] * (1.0 - f)
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
