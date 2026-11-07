class_name Bot
extends RefCounted
## 탐욕(greedy) 봇: 현재 모양으로 가장 많이 부술 수 있는 위치를 고른다.
## 자동 플레이 시연, 판정 기준(최대 파괴 수) 계산, 밸런스 시뮬레이션에 사용한다.


static func best_move(model: BoardModel, offsets: Array) -> Dictionary:
	var best := {"cell": Vector2i(-1, -1), "count": 0}
	for y in model.rows:
		for x in model.cols:
			var cell := Vector2i(x, y)
			var n: int = model.compute_break(cell, offsets)["all"].size()
			if n > best["count"]:
				best = {"cell": cell, "count": n}
	return best


## 모든 자리의 파괴 수를 많은 순으로 정렬해 돌려준다.
static func all_moves(model: BoardModel, offsets: Array) -> Array:
	var out: Array = []
	for y in model.rows:
		for x in model.cols:
			var cell := Vector2i(x, y)
			out.append({"cell": cell, "count": model.compute_break(cell, offsets)["all"].size()})
	out.sort_custom(func(a, b): return a["count"] > b["count"])
	return out
