class_name BoardModel
extends RefCounted
## 보드의 순수 로직. 화면과 분리되어 있어 테스트와 봇 시뮬레이션에 그대로 쓸 수 있다.

const EMPTY := -1
const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var cols: int
var rows: int
var num_colors: int
## 새 블록이 이웃 블록 색을 따라갈 확률. 높을수록 같은 색 덩어리가 커진다.
var cluster_bias := 0.35
var cells := PackedInt32Array()
var rng := RandomNumberGenerator.new()


func _init(p_cols: int, p_rows: int, p_colors: int, seed_value: int = 0) -> void:
	cols = p_cols
	rows = p_rows
	num_colors = p_colors
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	cells.resize(cols * rows)
	cells.fill(EMPTY)


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < cols and p.y < rows


func get_cell(p: Vector2i) -> int:
	return cells[p.y * cols + p.x]


func set_cell(p: Vector2i, value: int) -> void:
	cells[p.y * cols + p.x] = value


func fill_initial() -> void:
	# 아래에서 위로 채워야 "아래 이웃" 색을 참고할 수 있다.
	for y in range(rows - 1, -1, -1):
		for x in cols:
			var p := Vector2i(x, y)
			set_cell(p, pick_color(p))


## 새 블록 색 결정. 일정 확률로 아래/왼쪽 이웃 색을 따라가 덩어리를 만든다.
func pick_color(p: Vector2i) -> int:
	if rng.randf() < cluster_bias:
		var candidates: Array = []
		for n in [p + Vector2i(0, 1), p + Vector2i(-1, 0)]:
			if in_bounds(n) and get_cell(n) != EMPTY:
				candidates.append(get_cell(n))
		if not candidates.is_empty():
			return candidates[rng.randi_range(0, candidates.size() - 1)]
	return rng.randi_range(0, num_colors - 1)


## 모양을 anchor에 찍었을 때 부서질 칸을 계산한다. 보드는 바꾸지 않는다(미리보기용).
## stamp: 모양 영역 안의 블록, all: stamp + 각 블록과 같은 색으로 연결된 블록 전체(BFS).
func compute_break(anchor: Vector2i, offsets: Array) -> Dictionary:
	var stamp: Array = []
	var visited := {}
	for o in offsets:
		var p: Vector2i = anchor + o
		if in_bounds(p) and get_cell(p) != EMPTY and not visited.has(p):
			visited[p] = true
			stamp.append(p)
	var all: Array = stamp.duplicate()
	var head := 0
	while head < all.size():
		var cur: Vector2i = all[head]
		head += 1
		var color := get_cell(cur)
		for d in DIRS:
			var n: Vector2i = cur + d
			if in_bounds(n) and not visited.has(n) and get_cell(n) == color:
				visited[n] = true
				all.append(n)
	return {"stamp": stamp, "all": all}


## 블록을 제거하고 중력 낙하와 보충을 적용한다.
## 반환: moves [{from,to}], spawns [{to,color,from_y}] (from_y는 화면 밖 시작 줄)
func apply_break(targets: Array) -> Dictionary:
	for p in targets:
		set_cell(p, EMPTY)
	var moves: Array = []
	var spawns: Array = []
	for x in cols:
		var write := rows - 1
		for y in range(rows - 1, -1, -1):
			var p := Vector2i(x, y)
			var c := get_cell(p)
			if c == EMPTY:
				continue
			if y != write:
				set_cell(Vector2i(x, write), c)
				set_cell(p, EMPTY)
				moves.append({"from": p, "to": Vector2i(x, write)})
			write -= 1
		var missing := write + 1
		for y in range(write, -1, -1):
			var p := Vector2i(x, y)
			var color := pick_color(p)
			set_cell(p, color)
			spawns.append({"to": p, "color": color, "from_y": y - missing})
	return {"moves": moves, "spawns": spawns}


func is_full() -> bool:
	for c in cells:
		if c == EMPTY:
			return false
	return true
