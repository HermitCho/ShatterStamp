class_name PieceView
extends Control
## HOLD / NOW / NEXT 칸에 모양을 그려 주는 UI.

signal pressed

var title := ""
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

var _panel: StyleBoxFlat


func _ready() -> void:
	_panel = StyleBoxFlat.new()
	_panel.set_corner_radius_all(18)
	_panel.bg_color = Color(1, 1, 1, 0.09 if highlight else 0.05)
	if highlight:
		_panel.border_color = Color(1, 1, 1, 0.35)
		_panel.set_border_width_all(3)


func set_piece(c: Array) -> void:
	cells = c
	queue_redraw()


func _draw() -> void:
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var top := 0.0
	if title != "":
		draw_string(ThemeDB.fallback_font, Vector2(16, 32), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.55))
		top = 30.0
	if cells.is_empty():
		return
	var mn := Vector2i(99, 99)
	var mx := Vector2i(-99, -99)
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var dim := Vector2(mx - mn + Vector2i.ONE) * cell_px
	var area := Rect2(Vector2(0, top), size - Vector2(0, top))
	var origin := area.position + (area.size - dim) / 2.0
	var fill := Color(1, 1, 1, 0.3 if dimmed or cooldown > 0.0 else 0.92)
	var inset := maxf(2.0, cell_px * 0.08)
	for c in cells:
		var r := Rect2(origin + Vector2(c - mn) * cell_px + Vector2(inset, inset), Vector2(cell_px, cell_px) - Vector2(inset, inset) * 2.0)
		draw_rect(r, fill)
	if cooldown > 0.0:
		var w := (size.x - 40.0) * cooldown
		draw_rect(Rect2(Vector2((size.x - w) / 2.0, size.y - 18.0), Vector2(w, 6)), Color(1, 1, 1, 0.6))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
