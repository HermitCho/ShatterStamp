class_name Block
extends Node2D
## 보드 위 블록 하나의 화면 표현. 색마다 다른 기호를 넣어 색약 플레이어도 구분할 수 있게 한다.

const SIZE := 72.0
static var _boxes: Dictionary = {}

var color_id := 0
var tween: Tween


func _draw() -> void:
	match GameSkin.id:
		"neon":
			_draw_neon()
		_:
			var half := SIZE / 2.0
			draw_style_box(_box(color_id), Rect2(-half, -half, SIZE, SIZE))
			draw_rect(Rect2(-half + 12, -half + 7, SIZE - 24, 7), Color(1, 1, 1, 0.25))
			_draw_symbol(Vector2(0, -3), Color(1, 1, 1, 0.45))


## 네온: 어두운 속, 빛나는 테두리(바깥으로 번지는 빛 여러 겹).
func _draw_neon() -> void:
	var col := GameSkin.block(color_id)
	var half := SIZE / 2.0 - 3.0
	for i in 4:
		var g := 3.0 + i * 3.0
		draw_style_box(_neon_box(col, 0.16 - i * 0.035, 3.0), Rect2(-half - g, -half - g, (half + g) * 2, (half + g) * 2))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(col.darkened(0.8), 0.95)
	fill.set_corner_radius_all(12)
	draw_style_box(fill, Rect2(-half, -half, half * 2, half * 2))
	draw_style_box(_neon_box(col, 1.0, 3.0), Rect2(-half, -half, half * 2, half * 2))
	_draw_symbol(Vector2.ZERO, Color(col.lightened(0.25), 0.95))


func _neon_box(col: Color, alpha: float, width: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(col, alpha)
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(14)
	return sb


func _draw_symbol(c: Vector2, col: Color) -> void:
	match color_id:
		0:
			draw_circle(c, 13.0, col)
		1:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -15), c + Vector2(15, 12), c + Vector2(-15, 12)]), col)
		2:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(16, 0), c + Vector2(0, 16), c + Vector2(-16, 0)]), col)
		3:
			draw_rect(Rect2(c - Vector2(12, 12), Vector2(24, 24)), col)
		_:
			draw_rect(Rect2(c - Vector2(15, 5), Vector2(30, 10)), col)
			draw_rect(Rect2(c - Vector2(5, 15), Vector2(10, 30)), col)


static func _box(id: int) -> StyleBoxFlat:
	if not _boxes.has(id):
		var sb := StyleBoxFlat.new()
		var base: Color = GameSkin.block(id)
		sb.bg_color = base
		sb.set_corner_radius_all(16)
		sb.border_width_bottom = 7
		sb.border_color = base.darkened(0.38)
		_boxes[id] = sb
	return _boxes[id]
