class_name BoardOverlay
extends Node2D
## 배치 미리보기. 부서지지 않을 칸은 어둡게 덮고, 찍는 영역(굵은 흰 테두리)과
## 함께 부서질 연결 블록(깜빡이는 노란 테두리), 예상 파괴 개수를 표시한다.


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
	var model := board.model
	var dim: Color = GameSkin.c("dim")
	var link: Color = GameSkin.c("link")
	var line: Color = GameSkin.c("stamp_line")

	# 1) 영향 없는 칸을 어둡게 → 부서질 칸이 떠 보인다.
	for y in model.rows:
		for x in model.cols:
			var p := Vector2i(x, y)
			if not all.has(p):
				draw_rect(Rect2(Vector2(p) * Board.CELL, Vector2(Board.CELL, Board.CELL)), dim)

	# 2) 함께 부서질 연결 블록: 노란 테두리 + 깜빡임
	for p in all:
		if not stamp.has(p):
			var r := _rect(p, 5.0)
			draw_rect(r, Color(link, 0.12 + 0.22 * pulse))
			draw_rect(r, Color(link, 0.65 + 0.35 * pulse), false, 4.0)

	# 3) 찍는 영역: 굵은 흰 테두리(보드 밖 칸은 흐리게)
	for o in board.offsets:
		var p: Vector2i = board.anchor + o
		var inside := model.in_bounds(p)
		var r := _rect(p, 3.0)
		if inside:
			draw_rect(r, Color(line, 0.28))
			draw_rect(r.grow(1.0), GameSkin.c("stamp_shadow"), false, 8.0)
			draw_rect(r, line, false, 5.0)
		else:
			draw_rect(r, Color(line, 0.06))
			draw_rect(r, Color(line, 0.25), false, 3.0)

	var n := all.size()
	if n > 0:
		_draw_count(all, n)


## 예상 파괴 개수를 부서질 영역 "바로 위"에 띄운다(블록에 겹쳐 묻히지 않게).
## 영역이 맨 윗줄에 닿으면 위쪽은 HUD에 가려지므로 영역 아래에 둔다.
func _draw_count(all: Array, n: int) -> void:
	var top := 999
	var bottom := -1
	var sum_x := 0.0
	for p in all:
		top = mini(top, p.y)
		bottom = maxi(bottom, p.y)
		sum_x += p.x
	var cx := (sum_x / all.size() + 0.5) * Board.CELL
	var w := 104.0
	var h := 50.0
	cx = clampf(cx, w / 2.0, board.model.cols * Board.CELL - w / 2.0)
	var y := top * Board.CELL - h - 4.0
	if top == 0:
		y = (bottom + 1) * Board.CELL + 4.0
		if bottom == board.model.rows - 1:  # 위아래 끝까지 닿으면 찍는 칸 위에 둔다
			y = board.anchor.y * Board.CELL - h / 2.0
	var box := Rect2(Vector2(cx - w / 2.0, y), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameSkin.c("pill")
	sb.border_color = Color(GameSkin.c("pill_text"), 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(25)
	draw_style_box(sb, box)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(box.position.x, box.position.y + 37), "+%d" % n, HORIZONTAL_ALIGNMENT_CENTER, w, 34, GameSkin.c("pill_text"))


func _rect(p: Vector2i, inset: float) -> Rect2:
	return Rect2(Vector2(p) * Board.CELL + Vector2(inset, inset), Vector2(Board.CELL - inset * 2, Board.CELL - inset * 2))
