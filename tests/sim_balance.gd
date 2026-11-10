extends SceneTree
## 밸런스 시뮬레이션. 여러 성향의 봇으로 GameRules를 돌려 결과를 비교한다.
## 실행: Godot --headless --path . --script res://tests/sim_balance.gd [-- --runs=40 --base=600 --growth=25]
##
## 봇 종류 (interval = 한 번 찍는 데 걸리는 생각 시간 범위)
## - spam      : 아무 데나 아주 빠르게 찍는다 (막 누르기)
## - sloppy    : 대충 괜찮은 자리(상위 절반)를 빠르게 찍는다
## - decent    : 최대의 75% 이상 되는 자리를 보통 속도로 찍는다
## - careful   : 항상 최대 자리를 천천히 찍는다
## - expert    : 항상 최대 자리를 빠르게 찍는다 (상한선)
## - scrub     : 판정 색 미리보기를 보며 마우스로 칸을 무작위로 훑는다(칸당 0.06~0.1초, 반응 0.25초).
##               PERFECT가 보이면 바로 찍고, 2초가 지나면 그때까지 본 가장 좋은 자리에 찍는다.

const BOTS: Array = [
	{"name": "spam", "min": 0.15, "max": 0.25, "pick": "random"},
	{"name": "sloppy", "min": 0.35, "max": 0.6, "pick": "half"},
	{"name": "decent", "min": 0.7, "max": 1.2, "pick": "great"},
	{"name": "careful", "min": 1.4, "max": 2.2, "pick": "best"},
	{"name": "expert", "min": 0.6, "max": 1.0, "pick": "best"},
	{"name": "scrub", "min": 0.06, "max": 0.1, "pick": "scrub"},
]

var runs := 40
var base := -1.0
var growth := -1.0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--base="):
			base = float(a.substr(7))
		elif a.begins_with("--growth="):
			growth = float(a.substr(9))
	print("bot      score   (min-max)        len   bonus  combo  P/G/G/M %")
	for bot in BOTS:
		_run_bot(bot)
	quit()


func _run_bot(bot: Dictionary) -> void:
	var scores: Array = []
	var lens := 0.0
	var bonus := 0.0
	var combos := 0.0
	var grades: Array = [0, 0, 0, 0]
	for r in runs:
		var res := _play(bot, 1000 + r)
		scores.append(res["score"])
		lens += res["length"]
		bonus += res["bonus"]
		combos += res["max_combo"]
		for g in 4:
			grades[g] += res["grades"][g]
	scores.sort()
	var total := 0
	for s in scores:
		total += s
	var gsum: int = grades[0] + grades[1] + grades[2] + grades[3]
	print("%-8s %6d  (%6d-%6d)  %5.1fs  %+5.1fs  %5.1f  %d/%d/%d/%d" % [
		bot["name"], total / runs, scores[0], scores[-1], lens / runs, bonus / runs, combos / runs,
		100 * grades[0] / gsum, 100 * grades[1] / gsum, 100 * grades[2] / gsum, 100 * grades[3] / gsum])


func _play(bot: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var model := BoardModel.new(8, 9, 5, seed_value)
	model.fill_initial()
	var queue := ShapeQueue.new(seed_value)
	var rules := GameRules.new()
	if base >= 0.0:
		rules.target_base = base
	if growth >= 0.0:
		rules.target_growth = growth
	rules.reset()
	while true:
		var cells: Array = queue.pop()["cells"]
		var options := Bot.all_moves(model, cells)
		var best_n: int = options[0]["count"]
		var mv: Dictionary
		var wait: float
		if bot["pick"] == "scrub":
			var res := _scrub(options, best_n, bot, rng)
			mv = res[0]
			wait = res[1]
		else:
			wait = rng.randf_range(bot["min"], bot["max"])
			mv = _pick(bot["pick"], options, best_n, rng)
		rules.tick(maxf(wait, GameRules.STAMP_COOLDOWN))
		if rules.is_over():
			break
		var info := model.compute_break(mv["cell"], cells)
		rules.register_break(info["all"].size(), best_n)
		model.apply_break(info["all"], queue.peek(1)[0]["cells"])
		if rules.is_over():
			break
	return {
		"score": rules.score, "length": rules.elapsed, "bonus": rules.bonus_time_total,
		"max_combo": rules.max_combo, "grades": rules.grade_counts,
	}


## 무작위 순서로 칸을 훑다가 PERFECT를 보면 찍는다. [고른 자리, 걸린 시간]
func _scrub(options: Array, best_n: int, bot: Dictionary, rng: RandomNumberGenerator) -> Array:
	var order := options.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var t := 0.25
	var seen: Dictionary = order[0]
	for o in order:
		t += rng.randf_range(bot["min"], bot["max"])
		if o["count"] > seen["count"]:
			seen = o
		if o["count"] >= best_n or t >= 2.0:
			break
	return [seen, t]


func _pick(kind: String, options: Array, best_n: int, rng: RandomNumberGenerator) -> Dictionary:
	match kind:
		"best":
			return options[0]
		"great":
			var good: Array = options.filter(func(o): return o["count"] >= best_n * 0.75)
			return good[rng.randi_range(0, good.size() - 1)]
		"half":
			var half: Array = options.slice(0, maxi(1, options.size() / 2))
			return half[rng.randi_range(0, half.size() - 1)]
	return options[rng.randi_range(0, options.size() - 1)]
