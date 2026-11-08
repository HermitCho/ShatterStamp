class_name GameSkin
extends RefCounted
## 화면 테마(스킨). 색과 그리기 방식을 한곳에 모아 둔다.
## neon = 확정 테마(기본). classic = 이전 모습(비교용, 실행 인자 `-- --skin=classic`).
## 2026-11-09 시안 비교에서 잉크 도장 / 크리스탈은 기각되어 지웠다.

const IDS: Array = ["neon", "classic"]

static var id := "neon"

const DATA: Dictionary = {
	"classic": {
		"bg": Color(0.07, 0.07, 0.11),
		"bg_fever": Color(0.22, 0.07, 0.24),
		"text": Color.WHITE,
		"score": Color.WHITE,
		"score_glow": Color(0, 0, 0, 0.7),
		"time_text": Color.WHITE,
		"time_glow": Color(0, 0, 0, 0.7),
		"outline": Color(0, 0, 0, 0.7),
		"outline_scale": 1.0,
		"accent": Color(1.0, 0.85, 0.35),
		"on_accent": Color(0.08, 0.06, 0.1),
		"button": Color(0.2, 0.2, 0.28),
		"button_text": Color.WHITE,
		"button_border": Color(0, 0, 0, 0),
		"menu_dim": Color(0.03, 0.03, 0.06),
		"blocks": [Color(0.96, 0.33, 0.38), Color(1.0, 0.76, 0.27), Color(0.24, 0.84, 0.55), Color(0.31, 0.62, 1.0), Color(0.71, 0.48, 1.0)],
		"board_bg": Color(1, 1, 1, 0.04),
		"board_border": Color(0, 0, 0, 0),
		"slot": Color(1, 1, 1, 0.025),
		"panel": Color(1, 1, 1, 0.05),
		"panel_hi": Color(1, 1, 1, 0.09),
		"panel_border": Color(0, 0, 0, 0),
		"panel_border_hi": Color(1, 1, 1, 0.35),
		"piece": Color(1, 1, 1, 0.92),
		"piece_dim": Color(1, 1, 1, 0.3),
		"dim": Color(0.02, 0.02, 0.05, 0.28),
		"stamp_line": Color.WHITE,
		"stamp_shadow": Color(0, 0, 0, 0.6),
		"link": Color(1.0, 0.86, 0.35),
		"pill": Color(0.05, 0.05, 0.09, 0.9),
		"pill_text": Color.WHITE,
		"track": Color(1, 1, 1, 0.08),
		"time": Color(0.4, 0.9, 0.6),
		"warn": Color(1, 0.35, 0.35),
		"ring": Color(1, 1, 1, 0.9),
		"tiers": [Color(1, 1, 1), Color(1.0, 0.85, 0.35), Color(1.0, 0.5, 0.3), Color(1.0, 0.4, 0.9)],
		"grades": [Color(1.0, 0.9, 0.3), Color(0.45, 0.95, 1.0), Color(0.6, 1.0, 0.6), Color(1.0, 0.3, 0.3)],
	},
	# 네온 아케이드: 어두운 화면에 빛나는 테두리. 점수는 분홍, 시간 숫자는 노랑, 시간 막대는 하늘색으로 서로 구분.
	"neon": {
		"bg": Color(0.03, 0.02, 0.07),
		"bg_fever": Color(0.14, 0.02, 0.16),
		"text": Color(0.92, 0.98, 1.0),
		"score": Color(1.0, 0.42, 0.88),
		"score_glow": Color(1.0, 0.2, 0.75, 0.55),
		"time_text": Color(1.0, 0.86, 0.3),
		"time_glow": Color(1.0, 0.7, 0.15, 0.55),
		"outline": Color(0.25, 0.85, 1.0, 0.55),
		"outline_scale": 1.3,
		"accent": Color(0.25, 0.95, 1.0),
		"on_accent": Color(0.02, 0.05, 0.1),
		"button": Color(0.05, 0.05, 0.12),
		"button_text": Color(0.92, 0.98, 1.0),
		"button_border": Color(1.0, 0.25, 0.85, 0.9),
		"menu_dim": Color(0.02, 0.01, 0.05),
		"blocks": [Color(1.0, 0.23, 0.5), Color(1.0, 0.78, 0.2), Color(0.3, 1.0, 0.55), Color(0.25, 0.85, 1.0), Color(0.72, 0.4, 1.0)],
		"board_bg": Color(0.05, 0.04, 0.1),
		"board_border": Color(0.25, 0.85, 1.0, 0.45),
		"slot": Color(0.25, 0.85, 1.0, 0.05),
		"panel": Color(0.05, 0.04, 0.1),
		"panel_hi": Color(0.07, 0.05, 0.14),
		"panel_border": Color(0.25, 0.85, 1.0, 0.3),
		"panel_border_hi": Color(1.0, 0.25, 0.85),
		"piece": Color(0.25, 0.95, 1.0),
		"piece_dim": Color(0.25, 0.95, 1.0, 0.25),
		"dim": Color(0.0, 0.0, 0.02, 0.5),
		"stamp_line": Color.WHITE,
		"stamp_shadow": Color(0.25, 0.85, 1.0, 0.6),
		"link": Color(1.0, 0.25, 0.85),
		"pill": Color(0.03, 0.02, 0.07, 0.9),
		"pill_text": Color(0.25, 0.95, 1.0),
		"track": Color(0.25, 0.85, 1.0, 0.1),
		"time": Color(0.25, 0.95, 1.0),
		"warn": Color(1.0, 0.2, 0.2),
		"ring": Color(0.25, 0.95, 1.0, 0.95),
		"tiers": [Color(0.92, 0.98, 1.0), Color(0.25, 0.95, 1.0), Color(1.0, 0.78, 0.2), Color(1.0, 0.25, 0.85)],
		"grades": [Color(1.0, 0.25, 0.85), Color(0.25, 0.95, 1.0), Color(0.3, 1.0, 0.55), Color(1.0, 0.23, 0.5)],
	},
}


static func set_skin(new_id: String) -> void:
	id = new_id if DATA.has(new_id) else "neon"


static func c(key: String) -> Variant:
	return DATA[id][key]


static func block(color_id: int) -> Color:
	return DATA[id]["blocks"][color_id]
