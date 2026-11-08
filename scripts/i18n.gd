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
