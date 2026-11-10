class_name PieceView
extends Control
## HOLD / NOW / NEXT 칸에 모양을 그려 주는 UI.

signal pressed

var title := ""
## 칸 아래쪽에 작게 쓰는 안내(예: 키 이름)
var hint := ""
var title_size := 20
var cells: Array = []
var cell_px := 28.0
var highlight := false
var dimmed := false
## 0이면 사용 가능, 0보다 크면 남은 쿨다운 비율(1 → 0). 바닥 막대와 흐린 모양으로 보여 준다.
var cooldown := 0.0:
	set(v):
		if not is_equal_approx(v, cooldown):
			cooldown = v
			queue_redraw()

## 모양을 그릴 때 더하는 이동량. slide_in()이 0으로 되돌리며 "밀려 들어오는" 느낌을 만든다.
var content_offset := Vector2.ZERO:
	set(v):
		content_offset = v
		queue_redraw()

var _panel: StyleBoxFlat
var _slide: Tween


func _ready() -> void:
	clip_contents = true  # 밀려 들어오는 모양이 칸 밖으로 삐져나오지 않게
	_panel = StyleBoxFlat.new()
	_panel.set_corner_radius_all(18)
	_panel.bg_color = GameSkin.c("panel_hi" if highlight else "panel")
	_panel.border_color = GameSkin.c("panel_border_hi" if highlight else "panel_border")
	if _panel.border_color.a > 0.0:
		_panel.set_border_width_all(3 if highlight else 2)


func set_piece(c: Array) -> void:
	cells = c
	queue_redraw()


## 모양이 from만큼 떨어진 곳에서 출발해 제자리로 미끄러져 들어온다.
func slide_in(from: Vector2, dur := 0.16) -> void:
	if _slide and _slide.is_valid():
		_slide.kill()
	content_offset = from
	_slide = create_tween()
	_slide.tween_property(self, "content_offset", Vector2.ZERO, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var top := 0.0
	if title != "":
		draw_string(get_theme_default_font(), Vector2(14, 10 + title_size), tr(title), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(GameSkin.c("text"), 0.6))
		top = title_size + 10.0
	var bottom := 0.0
	if hint != "":
		draw_string(get_theme_default_font(), Vector2(0, size.y - 12), tr(hint), HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(GameSkin.c("text"), 0.45))
		bottom = 22.0
	if cells.is_empty():
		return
	var mn := Vector2i(99, 99)
	var mx := Vector2i(-99, -99)
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var area := Rect2(Vector2(0, top), size - Vector2(0, top + bottom))
	var span := Vector2(mx - mn + Vector2i.ONE)
	# 5칸짜리 긴 모양도 칸 밖으로 넘치지 않게 필요하면 줄인다.
	var px := minf(cell_px, minf((area.size.x - 20.0) / span.x, (area.size.y - 8.0) / span.y))
	var dim := span * px
	var origin := area.position + (area.size - dim) / 2.0 + content_offset
	var fill: Color = GameSkin.c("piece_dim") if dimmed or cooldown > 0.0 else GameSkin.c("piece")
	var inset := maxf(1.5, px * 0.08)
	for c in cells:
		var r := Rect2(origin + Vector2(c - mn) * px + Vector2(inset, inset), Vector2(px, px) - Vector2(inset, inset) * 2.0)
		draw_rect(r, fill)
	if cooldown > 0.0:
		var w := (size.x - 40.0) * cooldown
		draw_rect(Rect2(Vector2((size.x - w) / 2.0, size.y - 18.0), Vector2(w, 6)), Color(GameSkin.c("text"), 0.6))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
