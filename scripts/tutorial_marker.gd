class_name TutorialMarker
extends Node2D
## 튜토리얼에서 "여기 찍어 보세요" 자리를 금색으로 깜빡이고, 위에서 화살표가 통통 튄다.

var cells: Array = []  ## 화면 좌표 Rect2
var hold_rect := Rect2()
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if not cells.is_empty() or hold_rect.has_area():
		queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 7.0)
	var gold := Color(1.0, 0.85, 0.3)
	if not cells.is_empty():
		var top := Vector2(0, 99999)
		var sum_x := 0.0
		for r in cells:
			var rr: Rect2 = r
			draw_rect(rr.grow(-2.0), Color(gold, 0.1 + 0.15 * pulse))
			draw_rect(rr.grow(-2.0 + pulse * 3.0), Color(gold, 0.55 + 0.45 * pulse), false, 4.0)
			top.y = minf(top.y, rr.position.y)
			sum_x += rr.get_center().x
		top.x = sum_x / cells.size()
		_arrow(top + Vector2(0, -14.0 - 12.0 * abs(sin(_t * 5.0))), gold)
	if hold_rect.has_area():
		draw_rect(hold_rect.grow(4.0 + pulse * 4.0), Color(gold, 0.5 + 0.5 * pulse), false, 5.0)
		_arrow(Vector2(hold_rect.get_center().x, hold_rect.position.y - 12.0 - 12.0 * abs(sin(_t * 5.0))), gold)


## 끝이 아래(tip)를 가리키는 화살표
func _arrow(tip: Vector2, c: Color) -> void:
	var pts := PackedVector2Array([tip, tip + Vector2(-22, -26), tip + Vector2(-9, -26), tip + Vector2(-9, -50),
		tip + Vector2(9, -50), tip + Vector2(9, -26), tip + Vector2(22, -26)])
	var outline := PackedVector2Array(pts)
	outline.append(tip)
	draw_colored_polygon(pts, c)
	draw_polyline(outline, Color(0, 0, 0, 0.6), 3.0, true)
