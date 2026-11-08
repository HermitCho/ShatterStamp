extends SceneTree
## 배경 음악을 코드로 합성해 assets/audio/*.wav 로 굽는다(외부 음원 없음).
## Godot --headless --path . --script res://tools/make_bgm.gd
##
## 웹 빌드는 실시간 합성(AudioStreamGenerator)을 기본 재생 방식에서 지원하지 않아서, 미리 파일로 만들어 둔다.
## 세 곡 모두 끝과 처음이 이어지도록(꼬리 소리는 처음으로 감아 넣음) 만들어 반복 재생해도 끊김이 없다.
##   bgm_title.wav : 96 BPM, 패드 + 느린 아르페지오(메아리) + 가벼운 킥
##   bgm_game.wav  : 128 BPM, 킥·스네어·하이햇 + 베이스 + 16분 아르페지오 + 패드
##   bgm_fever.wav : bgm_game과 길이가 같은 추가 층(멜로디 + 촘촘한 하이햇). 피버 때 겹쳐 튼다.

const SR := 32000
const OUT := "res://assets/audio/"

# A단조 진행: Am - F - C - G (코드당 2마디)
const CHORDS: Array = [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]]
const BASS: Array = [45, 41, 48, 43]
const MELODY: Array = [
	[[0, 76, 4], [4, 74, 2], [6, 72, 2], [8, 74, 4], [12, 76, 4]],
	[[0, 79, 6], [6, 76, 2], [8, 74, 8]],
	[[0, 72, 4], [4, 74, 2], [6, 76, 2], [8, 77, 4], [12, 76, 4]],
	[[0, 74, 6], [6, 72, 2], [8, 69, 8]],
	[[0, 72, 4], [4, 76, 2], [6, 79, 2], [8, 84, 4], [12, 83, 4]],
	[[0, 79, 8], [8, 76, 8]],
	[[0, 74, 4], [4, 79, 2], [6, 83, 2], [8, 81, 4], [12, 79, 4]],
	[[0, 74, 6], [6, 76, 2], [8, 71, 8]],
]

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 128
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_make_game(), "bgm_game.wav")
	_save(_make_fever(), "bgm_fever.wav")
	_save(_make_title(), "bgm_title.wav")
	quit()


static func freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# ---------------------------------------------------------------- 곡

func _make_game() -> PackedFloat32Array:
	var beat := SR * 60 / 128  # 15000
	var n := beat * 32
	var drums := _buf(n)
	var duck := _buf(n)  # 킥에 맞춰 눌리는 층(베이스, 패드)
	var arp := _buf(n)
	for b in 32:
		var t0 := b * beat
		_kick(drums, t0, 0.6)
		if b % 4 == 1 or b % 4 == 3:
			_snare(drums, t0, 0.32)
		_hat(drums, t0 + beat / 2, 0.09)
	for bar in 8:
		var ci := bar / 2
		var bar0 := bar * beat * 4
		for e in 8:  # 베이스 8분음: 뿌리음, 가끔 옥타브
			var note: int = BASS[ci] + (12 if e % 4 == 3 else 0)
			_bass(duck, bar0 + e * beat / 2, beat / 2, note, 0.26)
		var tones: Array = CHORDS[ci]
		var pattern := [0, 1, 2, 1, 0, 1, 2, 3, 0, 1, 2, 1, 2, 3, 2, 1]
		for s in 16:  # 16분 아르페지오
			var k: int = pattern[s]
			var note: int = (tones[0] + 12 + 12) if k == 3 else tones[k] + 12
			_pluck(arp, bar0 + s * beat / 4, beat / 4 * 2, note, 0.11, 0.25)
		if bar % 2 == 0:
			_pad(duck, bar0, beat * 8, tones, 0.05)
	_sidechain(duck, beat)
	return _mix([[drums, 1.0], [duck, 1.0], [_lowpass(arp, 0.35), 1.0]], n)


func _make_fever() -> PackedFloat32Array:
	var beat := SR * 60 / 128
	var n := beat * 32
	var lead := _buf(n)
	var drums := _buf(n)
	for bar in 8:
		var bar0 := bar * beat * 4
		for m in MELODY[bar]:
			_lead(lead, bar0 + m[0] * beat / 4, m[2] * beat / 4, m[1], 0.13)
		for s in 16:
			if s % 2 == 1:
				_hat(drums, bar0 + s * beat / 4, 0.05)
		_clap(drums, bar0 + beat * 2, 0.12)
	var echo := _echo(lead, beat * 3 / 4, 0.3)
	return _mix([[echo, 1.0], [drums, 1.0]], n)


func _make_title() -> PackedFloat32Array:
	var beat := SR * 60 / 96  # 20000
	var n := beat * 32
	var drums := _buf(n)
	var pad := _buf(n)
	var arp := _buf(n)
	for b in 32:
		if b % 2 == 0:
			_kick(drums, b * beat, 0.32)
		_hat(drums, b * beat + beat / 2, 0.035)
	for bar in 8:
		var ci := bar / 2
		var bar0 := bar * beat * 4
		var tones: Array = CHORDS[ci]
		if bar % 2 == 0:
			_pad(pad, bar0, beat * 8, tones, 0.08)
			_bass(pad, bar0, beat * 8, BASS[ci] - 12, 0.12)
		var pattern := [0, 2, 1, 2, 3, 2, 1, 2]
		for s in 8:
			var k: int = pattern[s]
			var note: int = (tones[0] + 24) if k == 3 else tones[k] + 12
			_pluck(arp, bar0 + s * beat / 2, beat, note, 0.1, 0.5)
	var arp_echo := _echo(_lowpass(arp, 0.25), beat * 3 / 4, 0.45)
	return _mix([[drums, 1.0], [pad, 1.0], [arp_echo, 1.0]], n)


# ---------------------------------------------------------------- 악기 (버퍼 길이를 넘는 꼬리는 처음으로 감아 넣는다)

func _buf(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	return b


func _add(buf: PackedFloat32Array, i: int, v: float) -> void:
	var n := buf.size()
	buf[i % n] += v


func _kick(buf: PackedFloat32Array, t0: int, vol: float) -> void:
	var ph := 0.0
	for i in int(SR * 0.32):
		var t := float(i) / SR
		ph += TAU * (45.0 + 95.0 * exp(-t * 30.0)) / SR
		_add(buf, t0 + i, sin(ph) * exp(-t * 8.0) * vol)


func _snare(buf: PackedFloat32Array, t0: int, vol: float) -> void:
	var lp := 0.0
	for i in int(SR * 0.2):
		var t := float(i) / SR
		var nz := rng.randf_range(-1.0, 1.0)
		lp += (nz - lp) * 0.5
		_add(buf, t0 + i, (lp * exp(-t * 18.0) + sin(TAU * 190.0 * t) * 0.6 * exp(-t * 35.0)) * vol)


func _clap(buf: PackedFloat32Array, t0: int, vol: float) -> void:
	for burst in 3:
		var o := t0 + burst * int(SR * 0.011)
		for i in int(SR * 0.12):
			var t := float(i) / SR
			_add(buf, o + i, rng.randf_range(-1.0, 1.0) * exp(-t * (40.0 if burst < 2 else 14.0)) * vol * 0.6)


func _hat(buf: PackedFloat32Array, t0: int, vol: float) -> void:
	var lp := 0.0
	for i in int(SR * 0.05):
		var t := float(i) / SR
		var nz := rng.randf_range(-1.0, 1.0)
		lp += (nz - lp) * 0.35
		_add(buf, t0 + i, (nz - lp) * exp(-t * 70.0) * vol)  # 고역만 남긴 잡음


func _bass(buf: PackedFloat32Array, t0: int, length: int, midi: int, vol: float) -> void:
	var f := freq(midi)
	var lp := 0.0
	var ph := 0.0
	for i in length:
		var t := float(i) / SR
		ph = fmod(ph + f / SR, 1.0)
		var saw := 2.0 * ph - 1.0
		var sq := 1.0 if ph < 0.5 else -1.0
		lp += ((saw * 0.6 + sq * 0.4) - lp) * 0.12
		var env := minf(1.0, t * 300.0) * (1.0 - 0.35 * minf(1.0, t * 6.0))
		var rel := minf(1.0, float(length - i) / (SR * 0.01))
		_add(buf, t0 + i, lp * env * rel * vol)


func _pluck(buf: PackedFloat32Array, t0: int, length: int, midi: int, vol: float, duty: float) -> void:
	var f := freq(midi)
	var ph := 0.0
	for i in length:
		var t := float(i) / SR
		ph = fmod(ph + f / SR, 1.0)
		var v := (1.0 if ph < duty else -1.0) * 0.6 + sin(ph * TAU) * 0.4
		_add(buf, t0 + i, v * exp(-t * 14.0) * minf(1.0, t * 800.0) * vol)


func _pad(buf: PackedFloat32Array, t0: int, length: int, tones: Array, vol: float) -> void:
	for midi in tones:
		for det in [-0.07, 0.07]:
			var f := freq(midi + det)
			var ph := rng.randf()
			var lp := 0.0
			for i in length:
				var t := float(i) / SR
				ph = fmod(ph + f / SR, 1.0)
				lp += ((2.0 * ph - 1.0) - lp) * 0.04
				var env := minf(1.0, t / 0.35) * minf(1.0, float(length - i) / (SR * 0.3))
				_add(buf, t0 + i, lp * env * vol)


func _lead(buf: PackedFloat32Array, t0: int, length: int, midi: int, vol: float) -> void:
	var f := freq(midi)
	var ph := 0.0
	var ph2 := 0.0
	var lp := 0.0
	for i in length:
		var t := float(i) / SR
		var vib := 1.0 + 0.006 * sin(TAU * 5.5 * t) * minf(1.0, maxf(0.0, t - 0.15) * 4.0)
		ph = fmod(ph + f * vib / SR, 1.0)
		ph2 = fmod(ph2 + f * vib * 1.005 / SR, 1.0)
		lp += (((2.0 * ph - 1.0) + (2.0 * ph2 - 1.0)) * 0.5 - lp) * 0.2
		var env := minf(1.0, t * 200.0) * (0.75 + 0.25 * exp(-t * 6.0)) * minf(1.0, float(length - i) / (SR * 0.02))
		_add(buf, t0 + i, lp * env * vol)


# ---------------------------------------------------------------- 가공

## 박마다 소리를 눌렀다 놓는다(킥이 또렷하게 들리고 "펌핑"되는 느낌).
func _sidechain(buf: PackedFloat32Array, beat: int) -> void:
	for i in buf.size():
		var t := float(i % beat) / SR
		buf[i] *= 1.0 - 0.6 * exp(-t * 9.0)


func _lowpass(buf: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var out := _buf(buf.size())
	var lp := 0.0
	for lap in 2:  # 두 바퀴 돌려 처음과 끝의 필터 상태를 이어 붙인다
		for i in buf.size():
			lp += (buf[i] - lp) * k
			if lap == 1:
				out[i] = lp
	return out


func _echo(buf: PackedFloat32Array, delay: int, fb: float) -> PackedFloat32Array:
	var out := buf.duplicate()
	var n := buf.size()
	for rep in 3:
		var g := pow(fb, rep + 1)
		for i in n:
			out[(i + delay * (rep + 1)) % n] += buf[i] * g
	return out


func _mix(layers: Array, n: int) -> PackedFloat32Array:
	var out := _buf(n)
	for l in layers:
		var b: PackedFloat32Array = l[0]
		var g: float = l[1]
		for i in n:
			out[i] += b[i] * g
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(out[i]))
	var norm := 0.9 / maxf(peak, 0.001)
	for i in n:
		out[i] = tanh(out[i] * norm * 1.1) / tanh(1.1)
	return out


func _save(buf: PackedFloat32Array, name: String) -> void:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	w.save_to_wav(OUT + name)
	print("%s: %.1f s" % [name, float(buf.size()) / SR])
