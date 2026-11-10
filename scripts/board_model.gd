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
## 보충 조정: 다음 모양의 최대 파괴 수 목표와 시도 횟수(1이면 조정 안 함)
var steer_target := 15
var steer_trials := 10
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
## next_offsets(다음에 쓸 모양)를 주면 "보충 조정"을 한다: 새 블록 색 조합을 여러 번 뽑아 보고,
## 그 모양으로 낼 수 있는 최대 파괴 수가 steer_target에 가장 가까운 조합을 고른다.
## → 화면에 보이는 NEXT 모양은 그대로, 아직 안 보인 새 블록 색만 골라 매 차례 최대치를 고르게 유지한다.
## 반환: moves [{from,to}], spawns [{to,color,from_y}] (from_y는 화면 밖 시작 줄)
func apply_break(targets: Array, next_offsets: Array = []) -> Dictionary:
	for p in targets:
		set_cell(p, EMPTY)
	var moves: Array = []
	var empties: Array = []  # 보충할 칸(왼쪽 열부터, 각 열은 아래에서 위로) + 화면 밖 시작 줄
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
			empties.append([Vector2i(x, y), y - missing])

	var colors := _fill(empties)
	if not next_offsets.is_empty() and not empties.is_empty() and steer_trials > 1:
		var best_err := absi(Bot.best_move(self, next_offsets)["count"] - steer_target)
		for i in steer_trials - 1:
			if best_err == 0:
				break
			for e in empties:
				set_cell(e[0], EMPTY)
			var trial := _fill(empties)
			var err := absi(Bot.best_move(self, next_offsets)["count"] - steer_target)
			if err < best_err:
				best_err = err
				colors = trial
		for i in empties.size():
			set_cell(empties[i][0], colors[i])

	var spawns: Array = []
	for i in empties.size():
		spawns.append({"to": empties[i][0], "color": colors[i], "from_y": empties[i][1]})
	return {"moves": moves, "spawns": spawns}


## 빈 칸들을 순서대로 채우고 고른 색 목록을 돌려준다.
func _fill(empties: Array) -> Array:
	var out: Array = []
	for e in empties:
		var color := pick_color(e[0])
		set_cell(e[0], color)
		out.append(color)
	return out


## 같은 색으로 상하좌우 이어진 덩어리마다 번호를 매긴다.
## 반환: ids(칸마다 덩어리 번호, 빈 칸 -1), sizes(덩어리 번호 → 칸 수)
func components() -> Dictionary:
	var ids := PackedInt32Array()
	ids.resize(cols * rows)
	ids.fill(-1)
	var sizes := PackedInt32Array()
	var stack := PackedInt32Array()
	for start in cols * rows:
		if ids[start] >= 0 or cells[start] == EMPTY:
			continue
		var id := sizes.size()
		var color := cells[start]
		var count := 0
		ids[start] = id
		stack.append(start)
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var x := i % cols
			var y := i / cols
			if x > 0 and ids[i - 1] < 0 and cells[i - 1] == color:
				ids[i - 1] = id
				stack.append(i - 1)
			if x < cols - 1 and ids[i + 1] < 0 and cells[i + 1] == color:
				ids[i + 1] = id
				stack.append(i + 1)
			if y > 0 and ids[i - cols] < 0 and cells[i - cols] == color:
				ids[i - cols] = id
				stack.append(i - cols)
			if y < rows - 1 and ids[i + cols] < 0 and cells[i + cols] == color:
				ids[i + cols] = id
				stack.append(i + cols)
		sizes.append(count)
	return {"ids": ids, "sizes": sizes}


func is_full() -> bool:
	for c in cells:
		if c == EMPTY:
			return false
	return true
