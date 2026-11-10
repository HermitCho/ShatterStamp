class_name Board
extends Node2D
## 보드 화면과 입력. 로직은 BoardModel에 맡기고, 여기서는 블록 노드 배치와 애니메이션만 처리한다.

signal broke(info: Dictionary)
## 잠금 중에 찍으려 했을 때
signal blocked
## stamp_filter가 거부한 자리에 찍으려 했을 때(튜토리얼에서 최선의 자리만 받을 때)
signal rejected(cell: Vector2i)

const CELL := 80.0
const NO_ANCHOR := Vector2i(-999, -999)
## 파괴가 찍은 칸에서 같은 색을 따라 번지는 속도(한 칸 거리당 초)와 전체 상한
const WAVE_STEP := 0.028
const WAVE_MAX := 0.2

var model: BoardModel
var blocks: Array = []
var offsets: Array = []
var anchor := NO_ANCHOR
var preview: Dictionary = {}
## 지금 모양으로 이 보드에서 가능한 최대 파괴 수(판정 기준). set_piece 때 계산한다.
var best_n := 0
## 다음 차례 모양. 부순 뒤 보충할 때 이 모양의 최대 파괴 수가 고르게 나오도록 새 블록 색을 고른다(BoardModel.apply_break).
var next_offsets: Array = []
var input_enabled := false
## true면 찍기를 받지 않는다(파괴 직후 쿨다운). 미리보기는 계속 보인다.
var locked := false
## 비어 있지 않으면 찍기 전에 물어본다: func(cell) -> bool. false면 찍지 않고 rejected를 보낸다.
var stamp_filter: Callable
## 피버 중이면 테두리가 무지개빛으로 돈다.
var fever := false:
	set(v):
		fever = v
		queue_redraw()

var _pressing := false
var _overlay: BoardOverlay
var _bg_box: StyleBoxFlat


func setup(cols: int, rows: int, colors: int, seed_value: int = 0) -> void:
	model = BoardModel.new(cols, rows, colors, seed_value)
	model.fill_initial()
	blocks.resize(cols * rows)
	_bg_box = StyleBoxFlat.new()
	_bg_box.bg_color = GameSkin.c("board_bg")
	_bg_box.set_corner_radius_all(20)
	_bg_box.border_color = GameSkin.c("board_border")
	_bg_box.set_border_width_all(3 if GameSkin.c("board_border").a > 0.0 else 0)
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
	best_n = Bot.best_move(model, cells)["count"] if not cells.is_empty() else 0
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
	# 찍은 칸(거리 0)에서 같은 색 이웃을 따라 번지며 차례로 터진다. 규칙이 눈에 보이게 하려는 연출.
	var depth := _wave_depth(stamp, targets)
	var max_d := 0
	for d in depth.values():
		max_d = maxi(max_d, d)
	var step := minf(WAVE_STEP, WAVE_MAX / maxf(1.0, max_d))
	var broken: Array = []
	for p in targets:
		var b: Block = blocks[_i(p)]
		var delay: float = depth[p] * step
		broken.append({"pos": position + cell_center(p) * scale, "color": b.color_id, "delay": delay})
		_pop_block(b, delay)
		blocks[_i(p)] = null
	var wave_time := max_d * step

	var res := model.apply_break(targets, next_offsets)
	var moving: Array = []
	for m in res["moves"]:
		moving.append([blocks[_i(m["from"])], m["from"], m["to"]])
		blocks[_i(m["from"])] = null
	for mv in moving:
		var b: Block = mv[0]
		var from: Vector2i = mv[1]
		var to: Vector2i = mv[2]
		blocks[_i(to)] = b
		_drop(b, to, to.y - from.y, wave_time)
	for s in res["spawns"]:
		var to: Vector2i = s["to"]
		var from_y: int = s["from_y"]
		var b := _make_block(s["color"], cell_center(Vector2i(to.x, from_y)))
		blocks[_i(to)] = b
		_drop(b, to, to.y - from_y, wave_time)

	broke.emit({
		"count": targets.size(),
		"stamp_count": stamp.size(),
		"broken": broken,
		"anchor_pos": position + cell_center(cell) * scale,
		"wave_time": wave_time,
	})
	return true


## 찍은 칸들에서 시작하는 너비 우선 거리. 부서질 칸끼리 상하좌우로만 이어진다.
func _wave_depth(stamp: Array, targets: Array) -> Dictionary:
	var inside := {}
	for p in targets:
		inside[p] = true
	var depth := {}
	var q: Array = []
	for p in stamp:
		depth[p] = 0
		q.append(p)
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in BoardModel.DIRS:
			var n: Vector2i = cur + d
			if inside.has(n) and not depth.has(n):
				depth[n] = depth[cur] + 1
				q.append(n)
	for p in targets:  # 안전장치: 혹시 못 닿은 칸은 마지막에
		if not depth.has(p):
			depth[p] = 0
	return depth


## 부서지는 블록: 차례가 오면 하얗게 번쩍 부풀었다가 사라진다.
func _pop_block(b: Block, delay: float) -> void:
	if b.tween and b.tween.is_valid():
		b.tween.kill()
	var t := b.create_tween()
	b.tween = t
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(b, "modulate", Color(2.2, 2.2, 2.2), 0.03)
	t.parallel().tween_property(b, "scale", Vector2.ONE * 1.18, 0.03)
	t.tween_property(b, "scale", Vector2.ZERO, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(b.queue_free)


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
				elif stamp_filter.is_valid() and not stamp_filter.call(cell):
					rejected.emit(cell)
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
		preview["grade"] = GameRules.grade_for(preview["all"].size(), best_n)
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


func _drop(b: Block, to: Vector2i, dist: int, delay := 0.0) -> void:
	if b.tween and b.tween.is_valid():
		b.tween.kill()
	b.scale = Vector2.ONE
	var t := b.create_tween()
	b.tween = t
	if delay > 0.0:
		t.tween_interval(delay)  # 위 블록은 번지는 파괴가 끝난 뒤에 떨어진다
	var dur := 0.06 + 0.017 * dist
	t.tween_property(b, "position", cell_center(to), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(b, "scale", Vector2(1.1, 0.88), 0.04)
	t.tween_property(b, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var _fever_t := 0.0


func _process(delta: float) -> void:
	if fever:
		_fever_t += delta
		queue_redraw()


func _draw() -> void:
	var size := board_size()
	var frame := Rect2(Vector2(-12, -12), size + Vector2(24, 24))
	draw_style_box(_bg_box, frame)
	if fever:
		# 테두리를 따라 색이 흐르는 피버 빛: 바깥으로 두 겹 + 색상이 시간에 따라 돈다.
		var glow := StyleBoxFlat.new()
		glow.draw_center = false
		glow.set_corner_radius_all(24)
		for i in 3:
			var c := Color.from_hsv(fmod(_fever_t * 0.6 + i * 0.08, 1.0), 0.7, 1.0, 0.75 - i * 0.22)
			glow.border_color = c
			glow.set_border_width_all(5 - i)
			draw_style_box(glow, frame.grow(4.0 + i * 6.0 + 2.0 * sin(_fever_t * 8.0)))
	for y in model.rows:
		for x in model.cols:
			var r := Rect2(Vector2(x, y) * CELL + Vector2(6, 6), Vector2(CELL - 12, CELL - 12))
			draw_rect(r, GameSkin.c("slot"))
