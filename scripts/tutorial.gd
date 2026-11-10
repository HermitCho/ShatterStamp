class_name Tutorial
extends CanvasLayer
## 첫 판 안내. 실제 보드 위에서 몇 번 찍어 보게 하며 규칙을 하나씩 알려 준다(시간은 흐르지 않음).
## 진행(언제 다음 단계로 갈지)은 main.gd가 정하고, 여기서는 안내 상자·찍을 자리 표시·건너뛰기만 그린다.

signal skip_pressed

const BOX_POS := Vector2(24, 1036)
const BOX_SIZE := Vector2(672, 176)

var _box: Panel
var _step_label: Label
var _text: Label
var _skip: Button
var _marker: TutorialMarker


func _ready() -> void:
	layer = 2
	_marker = TutorialMarker.new()
	add_child(_marker)

	_box = Panel.new()
	_box.position = BOX_POS
	_box.size = BOX_SIZE
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameSkin.c("button"), 0.94)
	sb.border_color = GameSkin.c("accent")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	_box.add_theme_stylebox_override("panel", sb)
	add_child(_box)

	_step_label = _label(20, Vector2(24, 14), 300, HORIZONTAL_ALIGNMENT_LEFT)
	_step_label.add_theme_color_override("font_color", GameSkin.c("accent"))
	_box.add_child(_step_label)
	_text = _label(27, Vector2(16, 50), BOX_SIZE.x - 32, HORIZONTAL_ALIGNMENT_CENTER)
	_text.size.y = 110
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_text)

	_skip = Button.new()
	_skip.text = "TUT_SKIP"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.position = BOX_POS + Vector2(BOX_SIZE.x - 150, 8)
	_skip.size = Vector2(140, 40)
	_skip.add_theme_font_size_override("font_size", 20)
	_skip.add_theme_color_override("font_color", Color(GameSkin.c("text"), 0.75))
	_skip.add_theme_color_override("font_hover_color", GameSkin.c("text"))
	for k in ["normal", "hover", "pressed"]:
		var b := StyleBoxFlat.new()
		b.bg_color = Color(GameSkin.c("text"), 0.06 if k == "normal" else 0.16)
		b.set_corner_radius_all(14)
		_skip.add_theme_stylebox_override(k, b)
	_skip.pressed.connect(func(): skip_pressed.emit())
	add_child(_skip)
	visible = false


## step/total: 단계 표시, key: 번역 키, cells: 반짝일 칸(화면 좌표 Rect2 배열), hold_rect: HOLD 칸 강조(없으면 빈 Rect2)
func show_step(step: int, total: int, key: String, cells: Array, hold_rect := Rect2()) -> void:
	visible = true
	_step_label.text = "TUTORIAL  %d / %d" % [step, total] if step <= total else "TUTORIAL"
	_text.text = key
	_skip.visible = step <= total
	_marker.cells = cells
	_marker.hold_rect = hold_rect
	_marker.queue_redraw()
	_box.pivot_offset = BOX_SIZE / 2.0
	_box.scale = Vector2(0.94, 0.94)
	_box.create_tween().tween_property(_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 잘못 찍었을 때 안내 상자를 좌우로 살짝 흔든다.
func nudge() -> void:
	var x := BOX_POS.x
	var t := _box.create_tween()
	for dx in [10.0, -10.0, 6.0, -6.0, 0.0]:
		t.tween_property(_box, "position:x", x + dx, 0.04)


func set_cells(cells: Array) -> void:
	_marker.cells = cells
	_marker.queue_redraw()


func close() -> void:
	visible = false
	_marker.cells = []
	_marker.hold_rect = Rect2()
	_marker.queue_redraw()


func _label(font_size: int, pos: Vector2, width: float, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, font_size * 1.4)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", GameSkin.c("text"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
