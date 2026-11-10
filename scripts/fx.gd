class_name Fx
extends Node2D
## 가벼운 자체 파티클 시스템: 파편, 블록 섬광, 충격파 링.
## 노드를 만들지 않고 배열 + _draw로 처리해서 한 번에 수백 개가 터져도 가볍다.

const GRAVITY := 1800.0

var _parts: Array = []
var _flashes: Array = []
var _rings: Array = []
## 반짝이는 별(PERFECT)과 떠오르는 불꽃(FEVER) — 중력 영향이 작다.
var _stars: Array = []


func burst(pos: Vector2, color: Color, amount: int, power: float) -> void:
	for i in amount:
		var ang := randf() * TAU
		var spd := randf_range(0.35, 1.0) * power
		_parts.append({
			"p": pos + Vector2(randf_range(-18, 18), randf_range(-18, 18)),
			"v": Vector2(cos(ang), sin(ang)) * spd + Vector2(0, -power * 0.4),
			"t": 0.0,
			"max": randf_range(0.35, 0.7),
			"s": randf_range(7.0, 16.0),
			"c": color,
			"r": randf() * TAU,
			"rv": randf_range(-14.0, 14.0),
		})


func flash_cell(pos: Vector2, size: float, color: Color) -> void:
	_flashes.append({"p": pos, "s": size, "c": color.lerp(Color.WHITE, 0.75), "t": 0.0, "max": 0.16})


func ring(pos: Vector2, radius: float, color: Color) -> void:
	_rings.append({"p": pos, "r": radius, "c": color, "t": 0.0, "max": 0.38})


## PERFECT용 반짝이 별: 천천히 퍼지며 깜빡이다 사라진다.
func stars(pos: Vector2, color: Color, amount: int, power: float) -> void:
	for i in amount:
		var ang := randf() * TAU
		_stars.append({
			"p": pos, "v": Vector2(cos(ang), sin(ang)) * randf_range(0.4, 1.0) * power,
			"t": 0.0, "max": randf_range(0.5, 0.85), "s": randf_range(10.0, 20.0),
			"c": color, "g": 120.0, "drag": 3.2, "tw": randf() * TAU,
		})


## 피버 중 화면 아래에서 올라오는 불꽃.
func ember(pos: Vector2, color: Color) -> void:
	_stars.append({
		"p": pos, "v": Vector2(randf_range(-30, 30), randf_range(-420, -260)),
		"t": 0.0, "max": randf_range(0.7, 1.2), "s": randf_range(5.0, 10.0),
		"c": color, "g": 0.0, "drag": 0.6, "tw": randf() * TAU,
	})


func _process(delta: float) -> void:
	for i in range(_stars.size() - 1, -1, -1):
		var st: Dictionary = _stars[i]
		st["t"] += delta
		if st["t"] >= st["max"]:
			_stars.remove_at(i)
			continue
		st["v"] *= maxf(0.0, 1.0 - st["drag"] * delta)
		st["v"] += Vector2(0, st["g"] * delta)
		st["p"] += st["v"] * delta
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p["t"] += delta
		if p["t"] >= p["max"]:
			_parts.remove_at(i)
			continue
		p["v"] += Vector2(0, GRAVITY * delta)
		p["p"] += p["v"] * delta
		p["r"] += p["rv"] * delta
	_age(_flashes, delta)
	_age(_rings, delta)
	queue_redraw()


func _age(list: Array, delta: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		list[i]["t"] += delta
		if list[i]["t"] >= list[i]["max"]:
			list.remove_at(i)


func _draw() -> void:
	for f in _flashes:
		var k: float = f["t"] / f["max"]
		var s: float = f["s"] * (1.0 + 0.4 * k)
		draw_rect(Rect2(f["p"] - Vector2(s, s) / 2.0, Vector2(s, s)), Color(f["c"], 1.0 - k))
	for r in _rings:
		var k: float = r["t"] / r["max"]
		var e := 1.0 - pow(1.0 - k, 3.0)
		var c: Color = r["c"]
		draw_arc(r["p"], maxf(1.0, r["r"] * e), 0.0, TAU, 56, Color(c, c.a * (1.0 - k)), 10.0 * (1.0 - k) + 1.0, true)
	for p in _parts:
		var k: float = p["t"] / p["max"]
		var s: float = p["s"] * (1.0 - 0.5 * k)
		var col := Color(p["c"], 1.0 - k * k)
		match GameSkin.id:
			"neon":  # 빛 줄기: 진행 방향으로 늘어난 선
				var v: Vector2 = p["v"] * 0.02
				draw_line(p["p"] - v, p["p"], Color(col, col.a * 0.35), s * 0.7)
				draw_line(p["p"] - v * 0.5, p["p"], col.lightened(0.3), s * 0.3)
			_:
				draw_set_transform(p["p"], p["r"])
				draw_rect(Rect2(-s / 2.0, -s / 2.0, s, s), col)
	draw_set_transform(Vector2.ZERO, 0.0)
	for st in _stars:
		var k: float = st["t"] / st["max"]
		var tw := 0.6 + 0.4 * sin(st["tw"] + st["t"] * 30.0)
		var s: float = st["s"] * (1.0 - k * 0.6) * tw
		var col := Color(st["c"], (1.0 - k) * tw)
		var p: Vector2 = st["p"]
		# 네 갈래 별: 가로·세로 가는 마름모 두 개 + 가운데 흰 점
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.22, 0), p + Vector2(0, s), p + Vector2(-s * 0.22, 0)]), col)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(0, -s * 0.22), p + Vector2(s, 0), p + Vector2(0, s * 0.22)]), col)
		draw_circle(p, s * 0.18, Color(1, 1, 1, col.a))
