class_name Fx
extends Node2D
## 가벼운 자체 파티클 시스템: 파편, 블록 섬광, 충격파 링.
## 노드를 만들지 않고 배열 + _draw로 처리해서 한 번에 수백 개가 터져도 가볍다.

const GRAVITY := 1800.0

var _parts: Array = []
var _flashes: Array = []
var _rings: Array = []


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


func _process(delta: float) -> void:
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
		draw_set_transform(p["p"], p["r"])
		draw_rect(Rect2(-s / 2.0, -s / 2.0, s, s), Color(p["c"], 1.0 - k * k))
	draw_set_transform(Vector2.ZERO, 0.0)
