class_name BoardOverlay
extends Node2D
## 배치 미리보기: 모양 영역(테두리)과 함께 부서질 연결 블록(깜빡임), 예상 파괴 개수를 표시한다.

var board: Board
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if board and not board.preview.is_empty():
		queue_redraw()


func _draw() -> void:
	if board == null or board.preview.is_empty():
		return
	var stamp: Array = board.preview["stamp"]
	var all: Array = board.preview["all"]
	var pulse := 0.5 + 0.5 * sin(_t * 12.0)

	for p in all:
		if not stamp.has(p):
			draw_rect(_rect(p, 6.0), Color(1, 1, 1, 0.16 + 0.2 * pulse))

	for o in board.offsets:
		var p: Vector2i = board.anchor + o
		var inside := board.model.in_bounds(p)
		var r := _rect(p, 3.0)
		draw_rect(r, Color(1, 1, 1, 0.32 if inside else 0.06))
		draw_rect(r, Color(1, 1, 1, 0.95 if inside else 0.25), false, 4.0)

	var n := all.size()
	if n > 0:
		var font := ThemeDB.fallback_font
		var pos := board.cell_center(board.anchor) + Vector2(-80, -Board.CELL * 0.75)
		var text := "+%d" % n
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 160, 36, 8, Color(0, 0, 0, 0.75))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 160, 36, Color.WHITE)


func _rect(p: Vector2i, inset: float) -> Rect2:
	return Rect2(Vector2(p) * Board.CELL + Vector2(inset, inset), Vector2(Board.CELL - inset * 2, Board.CELL - inset * 2))
