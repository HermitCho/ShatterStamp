class_name HowtoCard
extends Control
## 게임 방법 카드 한 장: 왼쪽 그림(코드로 그림, 실제 게임과 같은 표시 방식) + 오른쪽 제목과 짧은 설명.
## kind: 0 = 찍으면 번진다, 1 = 판정 색, 2 = 콤보와 시간

const PIC_W := 236.0

var kind := 0
var title_key := ""
var body_key := ""

var _title: Label
var _body: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _make_label(title_key, 30, Vector2(PIC_W + 20, 22))
	_title.add_theme_color_override("font_color", GameSkin.c("accent"))
	add_child(_title)
	_body = _make_label(body_key, 24, Vector2(PIC_W + 20, 70))
	_body.size.y = size.y - 80
	_body.add_theme_constant_override("line_spacing", 4)
	add_child(_body)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _make_label(key: String, fs: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = key
	l.position = pos
	l.size = Vector2(size.x - pos.x - 16, fs * 1.4)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", GameSkin.c("text"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameSkin.c("panel")
	sb.border_color = GameSkin.c("panel_border")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var pic := Rect2(Vector2(14, 14), Vector2(PIC_W - 14, size.y - 28))
	match kind:
		0:
			_draw_spread(pic)
		1:
			_draw_grades(pic)
		_:
			_draw_combo(pic)


## 찍은 3칸 중 한 칸만 분홍 덩어리에 걸쳐도 → 분홍 덩어리 전체가 함께 부서진다(금색 윤곽).
## 부서지는 칸은 실제 규칙(BoardModel)으로 계산한다.
func _draw_spread(pic: Rect2) -> void:
	var grid := ["31002", "40012", "10432", "23141"]
	var model := BoardModel.new(5, 4, 5, 1)
	for y in 4:
		for x in 5:
			model.set_cell(Vector2i(x, y), int(grid[y][x]))
	var stamp := [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]
	var anchor := Vector2i(1, 2)
	var hit := {}
	for p in model.compute_break(anchor, stamp)["all"]:
		hit[p] = true
	var cs := 40.0
	var origin := pic.position + (pic.size - Vector2(5, 4) * cs) / 2.0
	for y in 4:
		for x in 5:
			var p := Vector2i(x, y)
			_block(Rect2(origin + Vector2(p) * cs, Vector2(cs, cs)), model.get_cell(p), hit.has(p))
	_contour(hit, origin, cs, GameSkin.c("grades")[0])
	for o in stamp:
		var p: Vector2i = anchor + o
		draw_rect(Rect2(origin + Vector2(p) * cs + Vector2(8, 8), Vector2(cs - 16, cs - 16)), Color.WHITE, false, 2.5)


## 판정 알약 네 개
func _draw_grades(pic: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var items := [["+15", 0], ["+12", 1], ["+9", 2], ["+4", 3]]
	var h := 40.0
	var gap := (pic.size.y - h * 4) / 3.0
	for i in 4:
		var col: Color = GameSkin.c("grades")[items[i][1]]
		var r := Rect2(pic.position + Vector2(8, i * (h + gap)), Vector2(pic.size.x - 16, h))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.01, 0.06, 0.94)
		sb.border_color = col
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(20)
		draw_style_box(sb, r)
		draw_string(font, r.position + Vector2(16, 29), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(font, r.position + Vector2(76, 28), GameRules.GRADE_NAMES[items[i][1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)


## 콤보 글자 + 줄어드는 막대 + FEVER x3 + 시간 +1초
func _draw_combo(pic: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var tiers: Array = GameSkin.c("tiers")
	var cx := pic.position.x + pic.size.x / 2.0
	var y := pic.position.y + 40.0
	draw_string(font, Vector2(pic.position.x, y), "10 COMBO", HORIZONTAL_ALIGNMENT_CENTER, pic.size.x, 34, tiers[3])
	draw_rect(Rect2(cx - 80, y + 14, 160, 6), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(cx - 50, y + 14, 100, 6), tiers[3])
	draw_string(font, Vector2(pic.position.x, y + 68), "FEVER! x3", HORIZONTAL_ALIGNMENT_CENTER, pic.size.x, 30, Color(1.0, 0.84, 0.2))
	draw_string(font, Vector2(pic.position.x, y + 118), I18n.t("SEC_FMT") % 1, HORIZONTAL_ALIGNMENT_CENTER, pic.size.x, 34, Color(0.4, 1.0, 0.6))


func _block(r: Rect2, color_id: int, lit: bool) -> void:
	var col := GameSkin.block(color_id)
	var inner := r.grow(-4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.22)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(7)
	draw_style_box(sb, inner)
	if not lit:
		draw_rect(r, GameSkin.c("dim"))


func _contour(cells: Dictionary, origin: Vector2, cs: float, col: Color) -> void:
	for pass_i in 2:
		var w := 9.0 if pass_i == 0 else 4.0
		var c := Color(0, 0, 0.03, 0.85) if pass_i == 0 else col
		for p in cells:
			var o: Vector2 = origin + Vector2(p) * cs
			if not cells.has(p + Vector2i(0, -1)):
				draw_line(o, o + Vector2(cs, 0), c, w)
			if not cells.has(p + Vector2i(0, 1)):
				draw_line(o + Vector2(0, cs), o + Vector2(cs, cs), c, w)
			if not cells.has(p + Vector2i(-1, 0)):
				draw_line(o, o + Vector2(0, cs), c, w)
			if not cells.has(p + Vector2i(1, 0)):
				draw_line(o + Vector2(cs, 0), o + Vector2(cs, cs), c, w)
