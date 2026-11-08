class_name Sfx
extends Node
## 효과음을 실행 시점에 코드로 합성한다(외부 음원 없음 → 저작권 걱정 없음).

const RATE := 22050

var _players: Array = []
var _next := 0
var _streams: Dictionary = {}


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	# dur, f0, f1, noise, decay, wave(0 sine, 1 square, 2 triangle)
	_streams["break"] = _synth(0.2, 260.0, 60.0, 0.55, 18.0, 2)
	_streams["pop"] = _synth(0.13, 700.0, 1150.0, 0.0, 26.0, 0)
	_streams["big"] = _synth(0.5, 140.0, 35.0, 0.75, 7.0, 2)
	_streams["tick"] = _synth(0.05, 1500.0, 1500.0, 0.0, 70.0, 0)
	_streams["hold"] = _synth(0.09, 500.0, 820.0, 0.0, 30.0, 2)
	_streams["start"] = _synth(0.3, 380.0, 950.0, 0.0, 7.0, 2)
	_streams["fever"] = _synth(0.7, 300.0, 1500.0, 0.05, 3.5, 1)
	_streams["end"] = _synth(0.8, 640.0, 160.0, 0.0, 3.0, 1)
	_streams["miss"] = _synth(0.28, 180.0, 90.0, 0.25, 9.0, 1)
	_streams["perfect"] = _synth(0.35, 880.0, 1760.0, 0.0, 9.0, 0)
	_streams["bonus"] = _synth(0.3, 600.0, 1200.0, 0.0, 8.0, 2)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	p.volume_db = volume_db
	p.play()


func _synth(dur: float, f0: float, f1: float, noise: float, decay: float, wave: int) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		phase += TAU * f / RATE
		var tone: float
		match wave:
			0:
				tone = sin(phase)
			1:
				tone = 0.5 if sin(phase) >= 0.0 else -0.5
			_:
				tone = asin(sin(phase)) * 2.0 / PI
		var s := tone * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		var env := minf(1.0, t / 0.004) * exp(-t * decay)
		data.encode_s16(i * 2, int(clampf(s * env * 0.8, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
