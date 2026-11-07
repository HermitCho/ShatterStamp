class_name Block
extends Node2D
## 보드 위 블록 하나의 화면 표현. 색마다 다른 기호를 넣어 색약 플레이어도 구분할 수 있게 한다.

const SIZE := 72.0
const COLORS: Array = [
	Color(0.96, 0.33, 0.38),
	Color(1.0, 0.76, 0.27),
	Color(0.24, 0.84, 0.55),
	Color(0.31, 0.62, 1.0),
	Color(0.71, 0.48, 1.0),
]

static var _boxes: Dictionary = {}

var color_id := 0
var tween: Tween


func _draw() -> void:
	var half := SIZE / 2.0
	draw_style_box(_box(color_id), Rect2(-half, -half, SIZE, SIZE))
	draw_rect(Rect2(-half + 12, -half + 7, SIZE - 24, 7), Color(1, 1, 1, 0.25))
	_draw_symbol(Vector2(0, -3), Color(1, 1, 1, 0.45))


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
		var base: Color = COLORS[id]
		sb.bg_color = base
		sb.set_corner_radius_all(16)
		sb.border_width_bottom = 7
		sb.border_color = base.darkened(0.38)
		_boxes[id] = sb
	return _boxes[id]
