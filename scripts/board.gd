class_name Board
extends Node2D
## 보드 화면과 입력. 로직은 BoardModel에 맡기고, 여기서는 블록 노드 배치와 애니메이션만 처리한다.

signal broke(info: Dictionary)
## 잠금 중에 찍으려 했을 때
signal blocked

const CELL := 80.0
const NO_ANCHOR := Vector2i(-999, -999)

var model: BoardModel
var blocks: Array = []
var offsets: Array = []
var anchor := NO_ANCHOR
var preview: Dictionary = {}
var input_enabled := false
## true면 찍기를 받지 않는다(파괴 직후 쿨다운). 미리보기는 계속 보인다.
var locked := false

var _pressing := false
var _overlay: BoardOverlay
var _bg_box: StyleBoxFlat


func setup(cols: int, rows: int, colors: int, seed_value: int = 0) -> void:
	model = BoardModel.new(cols, rows, colors, seed_value)
	model.fill_initial()
	blocks.resize(cols * rows)
	_bg_box = StyleBoxFlat.new()
	_bg_box.bg_color = Color(1, 1, 1, 0.04)
	_bg_box.set_corner_radius_all(20)
	_overlay = BoardOverlay.new()
	_overlay.board = self
	_overlay.z_index = 10
	add_child(_overlay)
	for y in rows:
		for x in cols:
			var p := Vector2i(x, y)
			var b := _make_block(model.get_cell(p), cell_center(p))
			blocks[_i(p)] = b
			b.scale = Vector2.ZERO
			b.tween = b.create_tween()
			b.tween.tween_interval(0.025 * (x + y))
			b.tween.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func board_size() -> Vector2:
	return Vector2(model.cols, model.rows) * CELL


func cell_center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * CELL


func set_piece(cells: Array) -> void:
	offsets = cells
	_refresh_preview()


func clear_preview() -> void:
	anchor = NO_ANCHOR
	_refresh_preview()


## 외부(봇, 테스트)에서도 같은 경로로 배치할 수 있도록 공개한다.
func place_at(cell: Vector2i) -> bool:
	if not model.in_bounds(cell):
		return false
	var info := model.compute_break(cell, offsets)
	var stamp: Array = info["stamp"]
	if stamp.is_empty():
		return false
	var targets: Array = info["all"]
	var broken: Array = []
	for p in targets:
		var b: Block = blocks[_i(p)]
		broken.append({"pos": position + cell_center(p), "color": b.color_id})
		b.queue_free()
		blocks[_i(p)] = null

	var res := model.apply_break(targets)
	var moving: Array = []
	for m in res["moves"]:
		moving.append([blocks[_i(m["from"])], m["from"], m["to"]])
		blocks[_i(m["from"])] = null
	for mv in moving:
		var b: Block = mv[0]
		var from: Vector2i = mv[1]
		var to: Vector2i = mv[2]
		blocks[_i(to)] = b
		_drop(b, to, to.y - from.y)
	for s in res["spawns"]:
		var to: Vector2i = s["to"]
		var from_y: int = s["from_y"]
		var b := _make_block(s["color"], cell_center(Vector2i(to.x, from_y)))
		blocks[_i(to)] = b
		_drop(b, to, to.y - from_y)

	broke.emit({
		"count": targets.size(),
		"stamp_count": stamp.size(),
		"broken": broken,
		"anchor_pos": position + cell_center(cell),
	})
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion:
		var lp := make_input_local(event) as InputEventMouse
		_set_anchor(_to_cell(lp.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var lp := make_input_local(event) as InputEventMouse
		var cell := _to_cell(lp.position)
		if event.pressed:
			_pressing = true
			_set_anchor(cell)
		elif _pressing:
			_pressing = false
			if model.in_bounds(cell):
				if locked:
					blocked.emit()
				else:
					place_at(cell)
				# 터치는 손가락을 떼면 미리보기를 숨긴다(마우스는 커서 위치에 계속 표시).
				if event.device == InputEvent.DEVICE_ID_EMULATION:
					clear_preview()
				else:
					_set_anchor(cell, true)


func _set_anchor(cell: Vector2i, force := false) -> void:
	var next := cell if model.in_bounds(cell) else NO_ANCHOR
	if next == anchor and not force:
		return
	anchor = next
	_refresh_preview()


func _refresh_preview() -> void:
	if anchor == NO_ANCHOR or offsets.is_empty():
		preview = {}
	else:
		preview = model.compute_break(anchor, offsets)
	if _overlay:
		_overlay.queue_redraw()


func _to_cell(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / CELL), floori(local.y / CELL))


func _i(p: Vector2i) -> int:
	return p.y * model.cols + p.x


func _make_block(color_id: int, pos: Vector2) -> Block:
	var b := Block.new()
	b.color_id = color_id
	b.position = pos
	add_child(b)
	move_child(b, 0)
	return b


func _drop(b: Block, to: Vector2i, dist: int) -> void:
	if b.tween and b.tween.is_valid():
		b.tween.kill()
	b.scale = Vector2.ONE
	var t := b.create_tween()
	b.tween = t
	var dur := 0.06 + 0.017 * dist
	t.tween_property(b, "position", cell_center(to), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(b, "scale", Vector2(1.1, 0.88), 0.04)
	t.tween_property(b, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var size := board_size()
	draw_style_box(_bg_box, Rect2(Vector2(-12, -12), size + Vector2(24, 24)))
	for y in model.rows:
		for x in model.cols:
			var r := Rect2(Vector2(x, y) * CELL + Vector2(6, 6), Vector2(CELL - 12, CELL - 12))
			draw_rect(r, Color(1, 1, 1, 0.025))
