class_name TitleLogo
extends Control
## 네온 타이틀 로고. play_intro()를 부르면
## 1) SHATTER 글자들이 흩어진 조각 자리에서 모여들고
## 2) STAMP가 도장처럼 위에서 쾅 찍힌다(이때 slammed 신호 → 효과음·흔들림은 Menus/Main이 처리).
## 이후에는 네온이 가끔 깜빡이고 STAMP가 살짝 숨 쉬듯 움직인다.

signal slammed

const CYAN := Color(0.3, 0.92, 1.0)
const PINK := Color(1.0, 0.28, 0.85)
const TOP_SIZE := 112
const STAMP_SIZE := 116
const LETTER_GAP := 4.0
const GATHER_TIME := 0.42
const GATHER_STAGGER := 0.05
const SLAM_AT := 0.78
const SLAM_TIME := 0.14

var _font: Font
var _letters: Array = []  # {ch, x, w, from, rot0}
var _t := 99.0
var _slam_done := true
var _flicker := 0.0
var _next_flicker := 2.0
var _shards: Array = []
var _rng := RandomNumberGenerator.new()
## SHATTER를 앞으로 기울이는 정도(속도감)
const SLANT := -0.22


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	_rng.randomize()
	var text := "SHATTER"
	var widths: Array = []
	var total := 0.0
	for ch in text:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TOP_SIZE).x
		widths.append(w)
		total += w + LETTER_GAP
	total -= LETTER_GAP
	var x := (size.x - total) / 2.0
	for i in text.length():
		_letters.append({"ch": text[i], "x": x, "w": widths[i], "from": Vector2.ZERO, "rot0": 0.0})
		x += widths[i] + LETTER_GAP


## 등장 연출을 처음부터 재생한다.
func play_intro() -> void:
	_t = 0.0
	_slam_done = false
	_shards.clear()
	for l in _letters:
		l["from"] = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(260.0, 520.0)
		l["rot0"] = _rng.randf_range(-2.5, 2.5)


## 연출이 끝난 상태로 바로 둔다.
func skip_intro() -> void:
	_t = 99.0
	_slam_done = true


func intro_length() -> float:
	return SLAM_AT + SLAM_TIME


func _process(delta: float) -> void:
	_t += delta
	if not _slam_done and _t >= SLAM_AT + SLAM_TIME:
		_slam_done = true
		_spawn_slam_shards()
		slammed.emit()
	# 네온 깜빡임: 몇 초에 한 번, 아주 짧게 두 번
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_flicker = 0.22
		_next_flicker = _rng.randf_range(2.5, 6.0)
	_flicker = maxf(0.0, _flicker - delta)
	for i in range(_shards.size() - 1, -1, -1):
		var s: Dictionary = _shards[i]
		s["t"] += delta
		if s["t"] >= s["max"]:
			_shards.remove_at(i)
			continue
		s["v"] *= 0.94
		s["p"] += s["v"] * delta
	queue_redraw()


func _spawn_slam_shards() -> void:
	var c := _stamp_center()
	for i in 34:
		var ang := _rng.randf() * TAU
		_shards.append({"p": c + Vector2(cos(ang) * 190.0, sin(ang) * 70.0), "v": Vector2.from_angle(ang) * _rng.randf_range(200.0, 560.0),
			"t": 0.0, "max": _rng.randf_range(0.3, 0.7), "c": PINK if i % 3 else CYAN})


func _stamp_center() -> Vector2:
	return Vector2(size.x / 2.0, 255.0)


func _draw() -> void:
	_draw_shatter()
	_draw_stamp()
	for s in _shards:
		var k: float = s["t"] / s["max"]
		var v: Vector2 = s["v"] * 0.04
		draw_line(s["p"] - v, s["p"], Color(s["c"], 1.0 - k), 4.0 * (1.0 - k) + 1.0)


func _draw_shatter() -> void:
	var base_y := 128.0
	# 깜빡임: 0.22초 동안 두 번 꺼졌다 켜진다
	var dim := 1.0
	if _flicker > 0.0 and fmod(_flicker, 0.11) > 0.055:
		dim = 0.35
	for i in _letters.size():
		var l: Dictionary = _letters[i]
		var p := clampf((_t - i * GATHER_STAGGER) / GATHER_TIME, 0.0, 1.0)
		if p <= 0.0:
			continue
		var e := 1.0 - pow(1.0 - p, 3.0)
		var off: Vector2 = l["from"] * (1.0 - e)
		var rot: float = l["rot0"] * (1.0 - e)
		var center := Vector2(l["x"] + l["w"] / 2.0, base_y - TOP_SIZE * 0.35) + off
		var xf := Transform2D(rot, center) * Transform2D(Vector2(1, 0), Vector2(SLANT, 1), Vector2.ZERO)
		draw_set_transform_matrix(xf)
		var a := minf(1.0, p * 2.0) * dim
		# 자리 잡는 순간 하얗게 번쩍
		var flash := clampf(1.0 - (p - 0.85) / 0.15, 0.0, 1.0) if p > 0.85 and p < 1.0 else 0.0
		_glow_text(Vector2(-l["w"] / 2.0, TOP_SIZE * 0.35), l["ch"], TOP_SIZE, CYAN.lerp(Color.WHITE, flash * 0.6), a)
	draw_set_transform(Vector2.ZERO, 0.0)
	var gathered := _t >= (_letters.size() - 1) * GATHER_STAGGER + GATHER_TIME
	if not gathered or _letters.is_empty():
		return
	# 오른쪽 끝에서 뒤로 흩날리는 파편
	var x1: float = _letters[-1]["x"] + _letters[-1]["w"] + 10.0
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in 9:
		var q := Vector2(x1 + r.randf_range(-6.0, 70.0), base_y - TOP_SIZE * r.randf_range(0.05, 0.75))
		_shard(q, r.randf_range(5.0, 12.0) * (1.0 - (q.x - x1) / 110.0), r.randf() * TAU, Color(CYAN, 0.75 * dim))


func _shard(c: Vector2, s: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.6, s * 0.5), Vector2(-s * 0.5, s * 0.6)])
	draw_set_transform(c, rot)
	draw_colored_polygon(pts, col)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_stamp() -> void:
	var p := clampf((_t - SLAM_AT) / SLAM_TIME, 0.0, 1.0)
	if p <= 0.0:
		return
	var e := p * p  # 가속하며 내려찍기
	var sc := lerpf(2.6, 1.0, e)
	if _slam_done:
		sc = 1.0 + 0.015 * sin(_t * 2.2)  # 숨 쉬기
		# 찍힌 직후 살짝 눌렸다 돌아오는 반동
		var since := _t - SLAM_AT - SLAM_TIME
		if since < 0.2:
			sc *= 1.0 - 0.06 * sin(since / 0.2 * PI)
	var c := _stamp_center()
	var a := minf(1.0, p * 1.5)
	draw_set_transform(c, deg_to_rad(-4.0), Vector2(sc, sc))
	var tw := _font.get_string_size("STAMP", HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_SIZE).x + 12.0 * 4
	var frame := Rect2(-tw / 2.0 - 34.0, -82.0, tw + 68.0, 156.0)
	# 도장 테두리(두 겹) + 빛
	for g in 4:
		_round_frame(frame.grow(4.0 + g * 5.0), Color(PINK, a * (0.16 - g * 0.035)), 5.0)
	_round_frame(frame, Color(PINK, a), 6.0)
	_round_frame(frame.grow(-12.0), Color(PINK, a * 0.6), 2.5)
	# 글자 간격을 넓혀 도장 글씨처럼
	var x := -tw / 2.0
	for ch in "STAMP":
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMP_SIZE).x
		_glow_text(Vector2(x, STAMP_SIZE * 0.36), ch, STAMP_SIZE, PINK, a)
		x += w + 12.0
	draw_set_transform(Vector2.ZERO, 0.0)


## 네온관 글씨: 바깥으로 번지는 빛 여러 겹 + 밝은 속.
func _glow_text(pos: Vector2, text: String, fs: int, col: Color, a: float) -> void:
	for g in [22, 14, 8]:
		draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, g, Color(col, a * (0.07 if g > 10 else 0.16)))
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(col, a))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.lerp(Color.WHITE, 0.65), a))


func _round_frame(r: Rect2, col: Color, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(26)
	draw_style_box(sb, r)
