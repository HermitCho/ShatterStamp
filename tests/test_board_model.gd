extends SceneTree
## 실행: Godot --headless --path . --script res://tests/test_board_model.gd

var _fails := 0
var _checks := 0


func _init() -> void:
	_test_connected_break()
	_test_stamp_out_of_bounds()
	_test_gravity_refill()
	_test_shapes_centered()
	_test_queue_bag()
	_test_random_runs()
	_test_rules()
	print("\n%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _model_from(rows_text: Array) -> BoardModel:
	var m := BoardModel.new(rows_text[0].length(), rows_text.size(), 5, 1)
	for y in rows_text.size():
		for x in rows_text[y].length():
			m.set_cell(Vector2i(x, y), int(rows_text[y][x]))
	return m


func _test_connected_break() -> void:
	var m := _model_from([
		"0011",
		"0211",
		"2222",
		"3332",
	])
	# 한 칸(0,0)만 찍어도 연결된 0 세 개가 부서진다.
	var info := m.compute_break(Vector2i(0, 0), [Vector2i(0, 0)])
	_check(info["stamp"].size() == 1, "stamp size 1")
	_check(info["all"].size() == 3, "connected 0 group = 3, got %d" % info["all"].size())
	# 0 영역과 1 영역 경계를 가로로 찍으면 두 덩어리 모두 부서진다.
	info = m.compute_break(Vector2i(1, 0), [Vector2i(0, 0), Vector2i(1, 0)])
	_check(info["all"].size() == 7, "0 group(3)+1 group(4)=7, got %d" % info["all"].size())
	# 2는 대각선이 아니라 상하좌우로만 연결된다.
	info = m.compute_break(Vector2i(1, 1), [Vector2i(0, 0)])
	_check(info["all"].size() == 6, "2 group = 6, got %d" % info["all"].size())


func _test_stamp_out_of_bounds() -> void:
	var m := _model_from(["01", "10"])
	var info := m.compute_break(Vector2i(1, 1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)])
	_check(info["stamp"].size() == 1, "out-of-bounds stamp cells ignored")


func _test_gravity_refill() -> void:
	var m := _model_from([
		"01",
		"23",
		"44",
	])
	var info := m.compute_break(Vector2i(0, 1), [Vector2i(0, 0)])
	var res := m.apply_break(info["all"])
	_check(m.is_full(), "board full after refill")
	_check(m.get_cell(Vector2i(0, 1)) == 0, "0 fell from row0 to row1")
	_check(m.get_cell(Vector2i(0, 2)) == 4, "bottom untouched")
	_check(res["moves"].size() == 1, "one move")
	_check(res["spawns"].size() == 1 and res["spawns"][0]["from_y"] == -1, "one spawn from above")


func _test_shapes_centered() -> void:
	for i in Shapes.LIST.size():
		var s := Shapes.get_shape(i)
		_check(s["cells"].has(Vector2i.ZERO), "%s anchor inside shape" % s["id"])


func _test_queue_bag() -> void:
	var q := ShapeQueue.new(42)
	var seen := {}
	for i in Shapes.LIST.size():
		seen[q.pop()["id"]] = true
	_check(seen.size() == Shapes.LIST.size(), "bag gives every shape once per cycle")


func _test_random_runs() -> void:
	# 무작위 보드에서 봇이 200번 부숴도 보드가 항상 꽉 차 있고 색 범위가 유효한지
	var m := BoardModel.new(8, 9, 5, 99)
	m.fill_initial()
	var q := ShapeQueue.new(7)
	var total := 0
	for i in 200:
		var cells: Array = q.pop()["cells"]
		var mv := Bot.best_move(m, cells)
		var info := m.compute_break(mv["cell"], cells)
		total += info["all"].size()
		m.apply_break(info["all"])
		if not m.is_full():
			_check(false, "board not full at step %d" % i)
			return
	for c in m.cells:
		if c < 0 or c >= 5:
			_check(false, "invalid color %d" % c)
			return
	_check(true, "random runs ok")
	print("greedy bot avg break per move: %.2f" % (float(total) / 200.0))


func _test_rules() -> void:
	# 판정: 최대 대비 비율
	_check(GameRules.grade_for(10, 10) == GameRules.Grade.PERFECT, "10/10 perfect")
	_check(GameRules.grade_for(8, 10) == GameRules.Grade.GREAT, "8/10 great")
	_check(GameRules.grade_for(5, 10) == GameRules.Grade.GOOD, "5/10 good")
	_check(GameRules.grade_for(4, 10) == GameRules.Grade.MISS, "4/10 miss")
	var r := GameRules.new()
	r.reset()
	# 좋은 자리 두 번 → 콤보 2, MISS → 콤보 끊김 + 시간 감소
	r.register_break(10, 10)
	r.tick(0.5)
	r.register_break(9, 10)
	_check(r.combo == 2, "combo continues on good stamps")
	var before := r.time_left
	var res := r.register_break(2, 10)
	_check(r.combo == 0 and res["combo_lost"], "miss breaks combo")
	_check(is_equal_approx(r.time_left, before - GameRules.MISS_PENALTY), "miss costs time")
	# 콤보 시간이 지나면 끊김
	r.register_break(10, 10)
	_check(r.tick(GameRules.COMBO_WINDOW + 0.01), "combo times out")
	# 시간 보너스 목표는 시간이 지날수록 오른다
	var t0 := r.time_target()
	r.tick(10.0)
	_check(r.time_target() > t0, "time target rises")
	# 목표 이상 점수만 시간 보너스
	r.reset()
	var small := r.register_break(3, 3)
	_check(small["time_delta"] == 0.0, "small perfect gives no time")
	var big := r.register_break(30, 30)
	_check(big["time_delta"] >= 1.0, "big stamp over target gives time, pts %d target %d" % [big["points"], big["target"]])
