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

const BOTS: Array = [
	{"name": "spam", "min": 0.15, "max": 0.25, "pick": "random"},
	{"name": "sloppy", "min": 0.35, "max": 0.6, "pick": "half"},
	{"name": "decent", "min": 0.7, "max": 1.2, "pick": "great"},
	{"name": "careful", "min": 1.4, "max": 2.2, "pick": "best"},
	{"name": "expert", "min": 0.6, "max": 1.0, "pick": "best"},
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
		var wait := maxf(rng.randf_range(bot["min"], bot["max"]), GameRules.STAMP_COOLDOWN)
		rules.tick(wait)
		if rules.is_over():
			break
		var cells: Array = queue.pop()["cells"]
		var options := Bot.all_moves(model, cells)
		var best_n: int = options[0]["count"]
		var mv: Dictionary = _pick(bot["pick"], options, best_n, rng)
		var info := model.compute_break(mv["cell"], cells)
		rules.register_break(info["all"].size(), best_n)
		model.apply_break(info["all"])
		if rules.is_over():
			break
	return {
		"score": rules.score, "length": rules.elapsed, "bonus": rules.bonus_time_total,
		"max_combo": rules.max_combo, "grades": rules.grade_counts,
	}


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
