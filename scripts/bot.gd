class_name Bot
extends RefCounted
## 탐욕(greedy) 봇: 현재 모양으로 가장 많이 부술 수 있는 위치를 고른다.
## 자동 플레이 시연, 판정 기준(최대 파괴 수) 계산, 밸런스 시뮬레이션에 사용한다.


## 빠른 계산: 같은 색 덩어리를 한 번만 번호 매기고(덩어리 크기 기록),
## 각 자리는 "모양이 닿는 서로 다른 덩어리 크기의 합"으로 센다. compute_break와 결과가 같다(테스트로 확인).
static func best_move(model: BoardModel, offsets: Array) -> Dictionary:
	var comp := model.components()
	var ids: PackedInt32Array = comp["ids"]
	var sizes: PackedInt32Array = comp["sizes"]
	var best := {"cell": Vector2i(-1, -1), "count": 0}
	var seen := {}
	for y in model.rows:
		for x in model.cols:
			seen.clear()
			var n := 0
			for o in offsets:
				var px: int = x + o.x
				var py: int = y + o.y
				if px < 0 or py < 0 or px >= model.cols or py >= model.rows:
					continue
				var id := ids[py * model.cols + px]
				if id >= 0 and not seen.has(id):
					seen[id] = true
					n += sizes[id]
			if n > best["count"]:
				best = {"cell": Vector2i(x, y), "count": n}
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
