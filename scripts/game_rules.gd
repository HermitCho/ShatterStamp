class_name GameRules
extends RefCounted
## 점수, 판정, 콤보, 시간 규칙. 화면과 분리되어 있어 게임(main.gd), 테스트, 밸런스 시뮬레이션이 같은 코드를 쓴다.
##
## 핵심 아이디어: 막 누르기보다 "지금 모양으로 가장 많이 부수는 자리"를 찾는 게 이득이어야 한다.
## - 판정: 찍은 자리의 파괴 수 / 현재 모양으로 가능한 최대 파괴 수 → PERFECT / GREAT / GOOD / MISS
## - MISS는 콤보를 끊고 시간을 깎는다.
## - 점수는 파괴 수의 제곱에 가깝게 늘어나고, 판정 배율과 콤보 배율이 곱해진다.
## - 시간 보너스는 1회 획득 점수가 "목표 점수"를 넘을 때만 주며, 목표 점수는 시간이 지날수록 오른다.

enum Grade { PERFECT, GREAT, GOOD, MISS }

const GRADE_NAMES: Array = ["PERFECT", "GREAT", "GOOD", "MISS"]
## 최대 파괴 수 대비 비율 기준
const GRADE_RATIO: Array = [1.0, 0.8, 0.6]
const GRADE_MULT: Array = [2.0, 1.5, 1.0, 0.5]

const GAME_TIME := 60.0
const MAX_TIME := 99.0
const MISS_PENALTY := 1.0
## 한 번 찍은 뒤 다음 찍기까지 막아 두는 시간(연타 방지)
const STAMP_COOLDOWN := 0.35
const COMBO_WINDOW := 2.4
const FEVER_BONUS_WINDOW := 0.4
## 콤보 단계: 0 = 1~2, 1 = 3~5, 2 = 6~9, 3 = 10+(피버)
const TIER_START: Array = [0, 3, 6, 10]
const TIER_MULT: Array = [1.0, 1.5, 2.0, 3.0]

## 시간 보너스 목표 점수 = TARGET_BASE + TARGET_GROWTH * 경과 초
var target_base := 1000.0
var target_growth := 90.0

var score := 0
var combo := 0
var max_combo := 0
var combo_timer := 0.0
var combo_window := COMBO_WINDOW
var time_left := GAME_TIME
var elapsed := 0.0
var total_broken := 0
var biggest := 0
var bonus_time_total := 0.0
var grade_counts: Array = [0, 0, 0, 0]


func reset() -> void:
	score = 0
	combo = 0
	max_combo = 0
	combo_timer = 0.0
	combo_window = COMBO_WINDOW
	time_left = GAME_TIME
	elapsed = 0.0
	total_broken = 0
	biggest = 0
	bonus_time_total = 0.0
	grade_counts = [0, 0, 0, 0]


## 시간을 흘린다. 콤보가 끊기면 true를 돌려준다.
func tick(delta: float) -> bool:
	time_left -= delta
	elapsed += delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			combo_timer = 0.0
			return true
	return false


func is_over() -> bool:
	return time_left <= 0.0


## 지금 시간 보너스를 받기 위한 1회 획득 점수 기준
func time_target() -> int:
	return int(target_base + target_growth * elapsed)


static func grade_for(n: int, best_n: int) -> int:
	if best_n <= 0 or n >= best_n:
		return Grade.PERFECT
	var ratio := float(n) / float(best_n)
	for g in GRADE_RATIO.size():
		if ratio >= GRADE_RATIO[g]:
			return g
	return Grade.MISS


static func tier_for(c: int) -> int:
	for t in range(TIER_START.size() - 1, -1, -1):
		if c >= TIER_START[t]:
			return t
	return 0


static func base_points(n: int) -> int:
	return n * n + n * 10


## 한 번 찍은 결과를 반영한다.
## n: 이번에 부순 블록 수, best_n: 현재 모양으로 가능했던 최대 파괴 수
func register_break(n: int, best_n: int) -> Dictionary:
	var grade := grade_for(n, best_n)
	grade_counts[grade] += 1
	total_broken += n
	biggest = maxi(biggest, n)

	var combo_lost := false
	if grade == Grade.MISS:
		combo_lost = combo > 0
		combo = 0
		combo_timer = 0.0
	else:
		combo = combo + 1 if combo_timer > 0.0 else 1
		max_combo = maxi(max_combo, combo)
	var tier := tier_for(combo)

	var points := int(base_points(n) * GRADE_MULT[grade] * TIER_MULT[tier])
	score += points

	var target := time_target()
	var time_delta := 0.0
	if grade == Grade.MISS:
		time_delta = -MISS_PENALTY
	elif points >= target * 2:
		time_delta = 2.0
	elif points >= target:
		time_delta = 1.0
	if time_delta > 0.0:
		bonus_time_total += time_delta
	time_left = minf(time_left + time_delta, MAX_TIME)

	if grade != Grade.MISS:
		combo_window = COMBO_WINDOW + (FEVER_BONUS_WINDOW if tier >= 3 else 0.0)
		combo_timer = combo_window

	return {
		"grade": grade,
		"points": points,
		"tier": tier,
		"combo": combo,
		"combo_lost": combo_lost,
		"time_delta": time_delta,
		"target": target,
		"best_n": best_n,
	}
