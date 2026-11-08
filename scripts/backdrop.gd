class_name Backdrop
extends Control
## 스킨별 배경(네온 격자와 위아래 번지는 빛).
## 화면 전체 기준 좌표로 같은 무늬를 그리므로, 상단 가림 패널로 하나 더 두어도 이음매가 보이지 않는다.

const SCREEN := Vector2(720, 1280)

## 바탕색. 피버 때 main이 트윈으로 바꾼다.
var tint := Color.BLACK:
	set(v):
		tint = v
		queue_redraw()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), tint)
	if GameSkin.id == "neon":
		_draw_grid()


func _draw_grid() -> void:
	var line := Color(0.25, 0.85, 1.0, 0.05)
	var step := 48.0
	for x in range(0, int(SCREEN.x) + 1, int(step)):
		draw_line(Vector2(x, 0), Vector2(x, SCREEN.y), line, 1.0)
	for y in range(0, int(SCREEN.y) + 1, int(step)):
		draw_line(Vector2(0, y), Vector2(SCREEN.x, y), line, 1.0)
	for i in 24:  # 아래쪽 분홍 빛
		var k := i / 24.0
		draw_rect(Rect2(0, SCREEN.y - 360 + k * 360, SCREEN.x, 15), Color(1.0, 0.2, 0.75, 0.012 + 0.04 * k))
	for i in 12:  # 위쪽 하늘색 빛
		var k := 1.0 - i / 12.0
		draw_rect(Rect2(0, i * 12.0, SCREEN.x, 12), Color(0.25, 0.85, 1.0, 0.03 * k))

