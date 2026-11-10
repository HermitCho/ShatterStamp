class_name BoardOverlay
extends Node2D
## 배치 미리보기. 신호는 "판정 색" 하나로 통일한다(깜빡임 없음).
## - 부서지지 않을 칸은 어둡게 덮는다 → 부서질 칸이 떠 보인다.
## - 부서질 영역 전체의 바깥 윤곽을 판정 색으로 두른다(금 PERFECT / 하늘 GREAT / 초록 GOOD / 빨강 MISS).
## - 찍는 칸은 얇은 흰 선.
## - 영역 위에 "+개수 판정" 알약을 같은 색으로 띄운다.

const EDGE := 5.0

var board: Board


func _draw() -> void:
	if board == null or board.preview.is_empty():
		return
	var all: Array = board.preview["all"]
	var grade: int = board.preview.get("grade", GameRules.Grade.PERFECT)
	var col: Color = GameSkin.c("grades")[grade]
	var model := board.model
	var cs := Board.CELL
	var inside := {}
	for p in all:
		inside[p] = true

	# 1) 영향 없는 칸을 어둡게
	var dim: Color = GameSkin.c("dim")
	for y in model.rows:
		for x in model.cols:
			var p := Vector2i(x, y)
			if not inside.has(p):
				draw_rect(Rect2(Vector2(p) * cs, Vector2(cs, cs)), dim)

	# 2) 부서질 칸: 판정 색을 아주 옅게 깔고, 영역의 바깥 윤곽만 굵게(어두운 그림자 위에 색 선)
	for p in all:
		draw_rect(Rect2(Vector2(p) * cs, Vector2(cs, cs)), Color(col, 0.14))
	for pass_i in 2:
		var w := EDGE + 6.0 if pass_i == 0 else EDGE
		var c := Color(0.0, 0.0, 0.03, 0.85) if pass_i == 0 else col
		for p in all:
			var o := Vector2(p) * cs
			if not inside.has(p + Vector2i(0, -1)):
				draw_line(o, o + Vector2(cs, 0), c, w)
			if not inside.has(p + Vector2i(0, 1)):
				draw_line(o + Vector2(0, cs), o + Vector2(cs, cs), c, w)
			if not inside.has(p + Vector2i(-1, 0)):
				draw_line(o, o + Vector2(0, cs), c, w)
			if not inside.has(p + Vector2i(1, 0)):
				draw_line(o + Vector2(cs, 0), o + Vector2(cs, cs), c, w)

	# 3) 찍는 칸: 얇은 흰 선 (보드 밖 칸은 흐리게)
	for o in board.offsets:
		var p: Vector2i = board.anchor + o
		var r := Rect2(Vector2(p) * cs + Vector2(12, 12), Vector2(cs - 24, cs - 24))
		draw_rect(r, Color(1, 1, 1, 0.9 if model.in_bounds(p) else 0.2), false, 3.0)

	if not all.is_empty():
		_draw_pill(all, grade, col)


## "+개수 판정" 알약을 부서질 영역 바로 위에 띄운다(영역이 맨 윗줄에 닿으면 아래에).
func _draw_pill(all: Array, grade: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var cs := Board.CELL
	var count_text := "+%d" % all.size()
	var grade_text: String = GameRules.GRADE_NAMES[grade]
	var fs_count := 34
	var fs_grade := 24
	var cw := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_count).x
	var gw := font.get_string_size(grade_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_grade).x
	var w := cw + gw + 52.0
	var h := 54.0

	var top := 999
	var bottom := -1
	var sum_x := 0.0
	for p in all:
		top = mini(top, p.y)
		bottom = maxi(bottom, p.y)
		sum_x += p.x
	var cx := (sum_x / all.size() + 0.5) * cs
	cx = clampf(cx, w / 2.0, board.model.cols * cs - w / 2.0)
	var y := top * cs - h - 8.0
	if top == 0:
		y = (bottom + 1) * cs + 8.0
		if bottom == board.model.rows - 1:  # 위아래 끝까지 닿으면 찍는 칸 위에 둔다
			y = board.anchor.y * cs - h / 2.0
	var box := Rect2(Vector2(cx - w / 2.0, y), Vector2(w, h))

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.01, 0.06, 0.94)
	sb.border_color = col
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(27)
	if grade == GameRules.Grade.PERFECT:
		sb.shadow_color = Color(col, 0.55)  # PERFECT만 은은한 빛
		sb.shadow_size = 14
	draw_style_box(sb, box)
	var x := box.position.x + 20.0
	var base := box.position.y + 38.0
	draw_string(font, Vector2(x, base), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_count, Color.WHITE)
	draw_string(font, Vector2(x + cw + 12.0, base - 2.0), grade_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_grade, col)
