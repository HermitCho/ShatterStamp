class_name TitleBackdrop
extends Control
## 타이틀 화면 배경(네온). 위에서부터: 어두운 하늘과 옅은 별, 지평선 빛, 앞으로 흘러오는 원근 격자 바닥,
## 그리고 천천히 떠오르며 돌다가 가끔 깨지는 네온 블록들.

const SIZE := Vector2(720, 1280)
const HORIZON := 930.0
const VANISH := Vector2(360, HORIZON)
const CYAN := Color(0.25, 0.9, 1.0)
const PINK := Color(1.0, 0.25, 0.85)
const FLOATERS := 10
## 로고가 있는 영역. 이 안을 지나는 블록은 흐리게 해서 로고를 가리지 않는다.
const LOGO_ZONE := Rect2(40, 120, 640, 440)

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _stars: Array = []
var _floaters: Array = []
var _shards: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	_rng.seed = 11
	for i in 70:
		_stars.append({"p": Vector2(_rng.randf() * SIZE.x, _rng.randf() * HORIZON * 0.9), "r": _rng.randf_range(0.6, 1.8), "ph": _rng.randf() * TAU})
	for i in FLOATERS:
		_floaters.append(_new_floater(true))
	_rng.randomize()


func _new_floater(anywhere: bool) -> Dictionary:
	var depth := _rng.randf_range(0.35, 1.0)  # 작을수록 멀리
	return {
		"p": Vector2(_rng.randf_range(20, SIZE.x - 20), _rng.randf_range(80, SIZE.y) if anywhere else SIZE.y + 60.0),
		"v": -_rng.randf_range(18.0, 45.0) * depth,
		"rot": _rng.randf() * TAU,
		"rv": _rng.randf_range(-0.6, 0.6),
		"s": 34.0 + 34.0 * depth,
		"a": 0.15 + 0.4 * depth,
		"c": _rng.randi_range(0, 4),
		"life": _rng.randf_range(4.0, 14.0),
	}


func _process(delta: float) -> void:
	_t += delta
	for i in _floaters.size():
		var f: Dictionary = _floaters[i]
		f["p"].y += f["v"] * delta
		f["rot"] += f["rv"] * delta
		f["life"] -= delta
		if f["life"] <= 0.0 and f["p"].y < SIZE.y - 40.0:
			_shatter(f)
			_floaters[i] = _new_floater(false)
		elif f["p"].y < -80.0:
			_floaters[i] = _new_floater(false)
	for i in range(_shards.size() - 1, -1, -1):
		var s: Dictionary = _shards[i]
		s["t"] += delta
		if s["t"] >= s["max"]:
			_shards.remove_at(i)
			continue
		s["v"] *= 0.97
		s["p"] += s["v"] * delta
	queue_redraw()


## 떠 있던 블록이 빛 조각으로 흩어진다.
func _shatter(f: Dictionary) -> void:
	var col := GameSkin.block(f["c"])
	for i in 14:
		var ang := _rng.randf() * TAU
		_shards.append({"p": f["p"], "v": Vector2.from_angle(ang) * _rng.randf_range(60.0, 220.0) * f["a"],
			"t": 0.0, "max": _rng.randf_range(0.5, 1.1), "c": col, "w": f["s"] * 0.12})


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.015, 0.06))
	# 하늘: 위는 짙은 남색, 지평선 쪽으로 보랏빛
	for i in 40:
		var k := i / 40.0
		draw_rect(Rect2(0, HORIZON * k, SIZE.x, HORIZON / 40.0 + 1.0), Color(0.03, 0.02, 0.09).lerp(Color(0.16, 0.03, 0.2), k * k))
	for s in _stars:
		var tw := 0.5 + 0.5 * sin(_t * 1.7 + s["ph"])
		draw_circle(s["p"], s["r"], Color(0.8, 0.95, 1.0, 0.15 + 0.35 * tw))
	_draw_floor()
	_draw_floaters()
	for s in _shards:
		var k: float = s["t"] / s["max"]
		var v: Vector2 = s["v"] * 0.05
		draw_line(s["p"] - v, s["p"], Color(s["c"], (1.0 - k) * 0.9), s["w"])


func _draw_floor() -> void:
	draw_rect(Rect2(0, HORIZON, SIZE.x, SIZE.y - HORIZON), Color(0.03, 0.01, 0.06))
	# 지평선 빛
	for i in 14:
		var k := 1.0 - i / 14.0
		draw_rect(Rect2(0, HORIZON - i * 5.0, SIZE.x, 5.0), Color(PINK, 0.05 * k))
		draw_rect(Rect2(0, HORIZON + i * 4.0, SIZE.x, 4.0), Color(PINK, 0.07 * k))
	draw_line(Vector2(0, HORIZON), Vector2(SIZE.x, HORIZON), Color(PINK, 0.9), 3.0)
	# 세로선: 소실점으로 모인다
	var depth := SIZE.y - HORIZON
	for i in range(-12, 13):
		var x_bottom := VANISH.x + i * 110.0
		draw_line(VANISH, Vector2(x_bottom, SIZE.y), Color(CYAN, 0.28), 1.5, true)
	# 가로선: 앞으로 흘러온다(원근: 가까울수록 간격이 넓다)
	var scroll := fmod(_t * 0.6, 1.0)
	for i in 12:
		var z := (i + 1.0 - scroll) / 12.0  # 0(먼 곳) → 1(가까운 곳)
		var y := HORIZON + depth * z * z
		draw_line(Vector2(0, y), Vector2(SIZE.x, y), Color(CYAN, 0.08 + 0.4 * z), 1.0 + 1.5 * z)


func _draw_floaters() -> void:
	for f in _floaters:
		var col := GameSkin.block(f["c"])
		var s: float = f["s"]
		var a: float = f["a"]
		if LOGO_ZONE.has_point(f["p"]):
			a *= 0.25
		draw_set_transform(f["p"], f["rot"])
		var r := Rect2(-s / 2.0, -s / 2.0, s, s)
		for g in 3:
			var gr := r.grow(3.0 + g * 4.0)
			draw_rect(gr, Color(col, a * (0.14 - g * 0.04)), false, 3.0)
		draw_rect(r, Color(col.darkened(0.8), a * 0.8))
		draw_rect(r, Color(col, a), false, 3.0)
		draw_rect(Rect2(-s * 0.16, -s * 0.16, s * 0.32, s * 0.32), Color(col.lightened(0.2), a * 0.8))
	draw_set_transform(Vector2.ZERO, 0.0)
