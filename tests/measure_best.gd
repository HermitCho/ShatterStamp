extends SceneTree
## 매 차례 "최대 파괴 수"가 얼마나 흔들리는지 잰다(항상 최고 자리에 찍는 봇 기준).
## 실행: Godot --headless --path . --script res://tests/measure_best.gd [-- --steps=3000 --steer=0|1]

var steps := 3000
var steer := true


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--steps="):
			steps = int(a.substr(8))
		elif a.begins_with("--steer="):
			steer = a.substr(8) == "1"
	var all: Array = []
	var by_shape := {}
	var games := 20
	for g in games:
		var model := BoardModel.new(8, 9, 5, 500 + g)
		model.fill_initial()
		var queue := ShapeQueue.new(500 + g)
		var cur: Dictionary = queue.pop()
		for i in steps / games:
			var mv := Bot.best_move(model, cur["cells"])
			var n: int = mv["count"]
			all.append(n)
			if not by_shape.has(cur["id"]):
				by_shape[cur["id"]] = []
			by_shape[cur["id"]].append(n)
			var info := model.compute_break(mv["cell"], cur["cells"])
			var nxt: Dictionary = queue.pop()
			if steer:
				model.apply_break(info["all"], nxt["cells"])
			else:
				model.apply_break(info["all"])
			cur = nxt
	print("steer=%s  ALL  %s" % [steer, _stats(all)])
	var ids := by_shape.keys()
	ids.sort()
	for id in ids:
		print("  %-8s %s" % [id, _stats(by_shape[id])])
	quit()


func _stats(a: Array) -> String:
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	var mean := sum / s.size()
	var var_sum := 0.0
	for v in s:
		var_sum += (v - mean) * (v - mean)
	var p := func(q: float) -> int: return s[int(q * (s.size() - 1))]
	return "mean %5.1f  sd %4.1f  p10 %2d  p50 %2d  p90 %2d  min %2d  max %2d" % [
		mean, sqrt(var_sum / s.size()), p.call(0.1), p.call(0.5), p.call(0.9), s[0], s[-1]]
