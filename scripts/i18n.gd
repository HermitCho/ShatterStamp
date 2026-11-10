class_name I18n
extends RefCounted
## 화면 문구 번역표. 키(ID)마다 [한국어, 영어]를 둔다. 기본 언어는 한국어.
##
## Label/Button의 text에 키를 그대로 넣으면 Godot가 자동 번역하고, 언어가 바뀌면 알아서 다시 그린다.
## 숫자가 들어가는 문구는 I18n.t("키") % 값 으로 만들고, 언어가 바뀔 때 다시 설정해야 한다.
##
## 한글 폰트(assets/fonts/game_font.ttf)는 이 파일에 나오는 글자만 남긴 서브셋이다.
## 한글 문구를 추가/수정하면 `python tools/build_font.py <원본 NotoSansKR.ttf>`로 폰트를 다시 만든다.
## PERFECT / COMBO / FEVER 같은 연출 문구는 두 언어 모두 영어로 둔다.

const LANGS: Array = ["ko", "en"]
const LANG_NAMES: Array = ["한국어", "English"]
const DEFAULT_LANG := "ko"

const STRINGS: Dictionary = {
	# HUD
	"SCORE": ["점수", "SCORE"],
	"TIME": ["시간", "TIME"],
	"BEST_FMT": ["최고 %d", "BEST %d"],
	"TARGET_FMT": ["%d점 이상 +1초", "+1s AT %d PTS"],
	"HOLD": ["홀드", "HOLD"],
	"NOW": ["지금", "NOW"],
	"NEXT": ["▲ 다음", "▲ NEXT"],
	"HOLD_HINT": ["스페이스 / 우클릭", "SPACE / R-CLICK"],
	"FOOTER": ["홀드: 스페이스 / Shift / C / 우클릭     일시정지: ESC", "HOLD: Space / Shift / C / right-click     PAUSE: ESC"],
	# 메뉴
	"TAGLINE": ["같은 색이 이어진 가장 큰 영역을 부숴라.", "Shatter the largest connected color area."],
	"START": ["시작", "START"],
	"HOW_TO_PLAY": ["게임 방법", "HOW TO PLAY"],
	"TUTORIAL_BTN": ["튜토리얼", "TUTORIAL"],
	"SETTINGS": ["설정", "SETTINGS"],
	"QUIT": ["종료", "QUIT"],
	"BACK": ["뒤로", "BACK"],
	"PAUSED": ["일시정지", "PAUSED"],
	"RESUME": ["계속하기", "RESUME"],
	"RESTART": ["다시 시작", "RESTART"],
	"TITLE": ["타이틀로", "TITLE"],
	"RETRY": ["다시 하기", "RETRY"],
	"SOUND_FMT": ["효과음  %d%%", "SOUND  %d%%"],
	"MUSIC_FMT": ["음악  %d%%", "MUSIC  %d%%"],
	"SHAKE_FMT": ["화면 흔들림: %s", "SCREEN SHAKE: %s"],
	"ON": ["켜짐", "ON"],
	"OFF": ["꺼짐", "OFF"],
	"LANGUAGE_FMT": ["언어: %s", "LANGUAGE: %s"],
	# 튜토리얼(첫 판)
	"TUT_1": ["NOW 모양을 보드에 찍어 보세요.\n같은 색 덩어리는 한 칸만 걸쳐도 다 터져요!", "Stamp the NOW shape on the board.\nTouch one block of a color group - the whole group breaks!"],
	"TUT_2": ["마우스를 움직여 금색 PERFECT가 뜨는 자리를\n찾아 찍으세요. 빨간 MISS는 시간 -1초!", "Move around to find a spot showing a gold PERFECT,\nthen stamp. A red MISS costs 1 second!"],
	"TUT_3": ["연달아 찍으면 COMBO가 쌓여요.\n콤보 막대가 사라지기 전에 한 번 더!", "Stamp again quickly to build a COMBO.\nOne more before the bar runs out!"],
	"TUT_4": ["오른쪽 HOLD 칸에 모양을 맡겨 둘 수 있어요.\n스페이스 / 우클릭 / HOLD 칸 터치", "Save a shape for later with HOLD.\nSpace / right-click / tap HOLD"],
	"TUT_5": ["준비 완료!\n60초 동안 최고 점수에 도전하세요.", "Ready!\nGo for a high score in 60 seconds."],
	"TUT_SKIP": ["건너뛰기", "SKIP"],
	"GRADE_SUB": ["%d개 / 최고 %d개", "%d of best %d"],
	"TUT_WRONG": ["금색 PERFECT 자리에 찍어 보세요!", "Stamp where it shows a gold PERFECT!"],
	# 게임 방법 카드
	"HOWTO_C1_T": ["찍으면 번져요", "Stamp & spread"],
	"HOWTO_C1_B": ["찍은 블록과 같은 색으로\n이어진 블록이 모두 터져요.\n한 칸만 걸쳐도 덩어리째!", "Every block linked to the\nstamped ones by the same\ncolor breaks. One touch = all!"],
	"HOWTO_C2_T": ["판정 색을 보세요", "Watch the color"],
	"HOWTO_C2_B": ["마우스를 올리면 미리 보여요.\n금색 PERFECT가 최고 자리.\n빨간 MISS는 -1초, 콤보 끊김.", "Hover to preview the grade.\nGold PERFECT = best spot.\nRed MISS: -1s, combo lost."],
	"HOWTO_C3_T": ["콤보와 시간", "Combo & time"],
	"HOWTO_C3_B": ["막대가 남았을 때 또 찍으면\n콤보! 10콤보 = FEVER x3.\n목표 점수를 넘기면 +1초.", "Stamp before the bar ends\nfor a COMBO. 10 = FEVER x3.\nBeat the target score: +1s."],
	"HOWTO_KEYS": ["홀드: 우클릭 / 스페이스     일시정지: ESC", "HOLD: right-click / Space     PAUSE: ESC"],
	# 결과
	"TIME_UP": ["시간 종료!", "TIME UP!"],
	"NEW_BEST": ["최고 기록 달성!", "NEW BEST!"],
	"R_MAX_COMBO": ["최대 콤보", "MAX COMBO"],
	"R_TIME": ["얻은 시간", "TIME EARNED"],
	"R_BIGGEST": ["최대 파괴", "BIGGEST BREAK"],
	"SEC_FMT": ["+%d초", "+%ds"],
	"COUNT_FMT": ["%d개", "%d"],
	"HOWTO_BODY": [
		"NOW 모양을 보드에 찍으세요.\n"
		+ "모양 아래 블록이 부서지고, 그 블록과\n"
		+ "이어진 같은 색 블록도 함께 부서집니다.\n\n"
		+ "찍을 때마다 그 모양의 최고 자리와\n"
		+ "비교해 판정합니다:\n"
		+ "PERFECT  x2     GREAT  x1.5     GOOD  x1\n"
		+ "MISS: 시간 -1초, 콤보 끊김.\n\n"
		+ "콤보 막대가 남아 있을 때 다시 찍으면\n"
		+ "콤보가 이어집니다. 10 COMBO = FEVER x3.\n\n"
		+ "한 번에 목표 점수 이상을 얻으면 +1초.\n"
		+ "목표 점수는 시간이 갈수록 오릅니다.\n\n"
		+ "홀드: 우클릭 / 스페이스 / HOLD 칸 터치\n"
		+ "일시정지: ESC / II 버튼",
		"Stamp the NOW shape onto the board.\n"
		+ "Blocks under it break - plus every\n"
		+ "same-color block connected to them.\n\n"
		+ "Each stamp is graded against the\n"
		+ "best spot for that shape:\n"
		+ "PERFECT  x2     GREAT  x1.5     GOOD  x1\n"
		+ "MISS: -1 second, combo lost.\n\n"
		+ "Stamp again within the combo bar\n"
		+ "to chain combos. 10 COMBO = FEVER x3.\n\n"
		+ "Score more than the TIME target in\n"
		+ "one stamp for +1s. The target rises.\n\n"
		+ "HOLD: right-click / Space / tap HOLD.\n"
		+ "Pause: ESC / tap II.",
	],
}

const FONT_PATH := "res://assets/fonts/game_font.ttf"

static var _ready_done := false


## 번역표를 TranslationServer에 올리고 폰트를 기본 폰트로 지정한다. 여러 번 불러도 한 번만 동작.
static func setup() -> void:
	if _ready_done:
		return
	_ready_done = true
	for i in LANGS.size():
		var table := Translation.new()
		table.locale = LANGS[i]
		for key in STRINGS:
			table.add_message(key, STRINGS[key][i])
		TranslationServer.add_translation(table)
	if ResourceLoader.exists(FONT_PATH):
		ThemeDB.fallback_font = load(FONT_PATH)
	set_lang(DEFAULT_LANG)


static func set_lang(code: String) -> void:
	if not LANGS.has(code):
		code = DEFAULT_LANG
	TranslationServer.set_locale(code)


static func lang() -> String:
	var cur := TranslationServer.get_locale()
	for code in LANGS:
		if cur.begins_with(code):
			return code
	return DEFAULT_LANG


## 다음 언어로 넘긴다(설정 화면의 언어 버튼).
static func next_lang() -> String:
	return LANGS[(LANGS.find(lang()) + 1) % LANGS.size()]


static func lang_name() -> String:
	return LANG_NAMES[LANGS.find(lang())]


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))
