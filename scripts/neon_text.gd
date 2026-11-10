class_name NeonText
extends Node2D
## 네온사인 글씨(타이틀 로고 STAMP와 같은 방식): 바깥으로 번지는 빛 여러 겹 + 색 관 + 밝은 속.
## frame_color의 알파가 0보다 크면 둥근 네온 테두리(두 겹)도 두른다. 원점이 글자 가운데.

var text := ""
var font_size := 160
var color := Color(0.3, 0.92, 1.0)
var frame_color := Color(0, 0, 0, 0)
## 켜짐 정도(0~1). 네온이 깜빡이며 켜지는 연출에 쓴다.
var glow := 1.0:
	set(v):
		glow = v
		queue_redraw()
var spacing := 10.0
## 속을 얼마나 하얗게 할지(0 = 테두리 색 그대로, 1 = 흰색)
var core_white := 0.45
## 테두리 안쪽 바탕(네온 간판의 어두운 판). 알파 0이면 비움.
var board_color := Color(0.02, 0.01, 0.06, 0.88)

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _draw() -> void:
	if _font == null:
		return
	var widths: Array = []
	var tw := 0.0
	for ch in text:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(w)
		tw += w
	tw += spacing * (text.length() - 1)
	var a := glow
	if frame_color.a > 0.0:
		var frame := Rect2(-tw / 2.0 - 40.0, -font_size * 0.56, tw + 80.0, font_size * 1.08)
		if board_color.a > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color(board_color, board_color.a * minf(1.0, a * 1.5))
			fill.set_corner_radius_all(30)
			draw_style_box(fill, frame)
		for g in 4:
			_frame(frame.grow(4.0 + g * 6.0), Color(frame_color, a * (0.18 - g * 0.04)), 6.0)
		_frame(frame, Color(frame_color, a), 7.0)
		_frame(frame.grow(-14.0), Color(frame_color, a * 0.55), 3.0)
	var x := -tw / 2.0
	var base_y := font_size * 0.36
	for i in text.length():
		var pos := Vector2(x, base_y)
		var ch := text[i]
		for g in [44, 30]:
			draw_string_outline(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, g, Color(color, a * (0.12 if g > 35 else 0.25)))
		# 얇은 어두운 테두리: 블록 위에서도 글자 윤곽이 묻히지 않게(빛 아래에 깔림)
		draw_string_outline(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 20, Color(0.02, 0.01, 0.06, a * 0.75))
		draw_string_outline(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 11, Color(color, a))
		draw_string(_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.lerp(Color.WHITE, core_white), a))
		x += widths[i] + spacing


func _frame(r: Rect2, col: Color, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(30)
	draw_style_box(sb, r)
