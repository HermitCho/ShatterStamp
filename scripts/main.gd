extends Node2D
## 게임 흐름(타이틀 → 플레이 → 결과), 점수/콤보/시간, HUD, 타격감 연출을 담당한다.

enum State { TITLE, PLAY, PAUSED, RESULT }

const COLS := 8
const ROWS := 9
const NUM_COLORS := 5
## 보드는 왼쪽, 모양 칸(HOLD/NOW/NEXT)은 오른쪽 세로 줄 — 시선을 보드 옆에만 두면 되게.
const BOARD_POS := Vector2(24, 400)
const BOARD_SCALE := 0.8
const SIDE_X := 552.0
const SIDE_W := 148.0
const SAVE_PATH := "user://save.cfg"
## 미리 보여 줄 다음 모양 개수
const NEXT_COUNT := 4

var state := State.TITLE
var rules := GameRules.new()
var best := 0
## 현재 모양으로 이 보드에서 가능한 최대 파괴 수(판정 기준)
var current_best_n := 0
var trauma := 0.0
var shake_enabled := true
var volume := 0.8
var music_volume := 0.7
var lang := I18n.DEFAULT_LANG
## 남은 찍기 금지 시간(연타 방지)
var stamp_lock := 0.0
var in_fever := false

var queue: ShapeQueue
var current: Dictionary = {}
var held: Dictionary = {}
var hold_used := false

var world: Node2D
var board: Board
var fx: Fx
var sfx: Sfx
var music: Music
var hud: CanvasLayer
var bg_rect: Backdrop
var top_panel: Backdrop
var score_label: Label
var best_label: Label
var time_label: Label
var time_bar: ColorRect
var target_label: Label
var combo_label: Label
var combo_bar: ColorRect
var hold_view: PieceView
var now_view: PieceView
var next_views: Array = []
var flash_rect: ColorRect
var pause_button: Button
var menus: Menus

var _last_tick := -1
var _autoplay := false
var _autoplay_timer := 0.0
## 지금 시간 숫자에 칠한 위험도(0 = 평소 색, 1 = 완전 빨강). 바뀔 때만 색을 다시 칠한다.
var _time_danger := -1.0
## 0이 아니면 보드와 모양 순서를 고정한다(시안 비교 스크린샷용).
var debug_seed := 0


func _ready() -> void:
	randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skin="):
			GameSkin.set_skin(a.substr(7))  # 디자인 시안 확인용
	I18n.setup()
	_load_save()
	I18n.set_lang(lang)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	bg_rect = _backdrop(Vector2(720, 1280))
	bg_layer.add_child(bg_rect)

	world = Node2D.new()
	add_child(world)
	fx = Fx.new()
	fx.z_index = 20
	world.add_child(fx)
	_ensure_buses()
	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	add_child(music)

	_build_hud()
	_build_menus()
	_apply_settings()
	_new_board()
	_show_title()

	var args := OS.get_cmdline_user_args()
	_autoplay = args.has("--autoplay")
	if _autoplay:
		_start_game()
	for a in args:
		if a.begins_with("--shots="):
			_capture_shots(a.substr(8))
		elif a.begins_with("--menu="):
			# 디버그: 특정 메뉴 화면을 바로 연다(스크린샷 확인용). pause는 게임을 시작한 뒤 연다.
			var m := a.substr(7)
			if m == "pause":
				_start_game()
				_pause.call_deferred()
			elif m == "settings":
				menus.show_panel.call_deferred("settings")
			elif m != "title":
				menus.show_panel.call_deferred(m)


## 디버그: 일정 간격으로 화면을 PNG로 저장한다(자동 플레이 확인용).
func _capture_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var i := 0
	while true:
		await get_tree().create_timer(1.3, true, false, true).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [dir, i])
		i += 1


# ---------------------------------------------------------------- 게임 흐름

func _new_board() -> void:
	if board:
		board.queue_free()
	board = Board.new()
	board.position = BOARD_POS
	board.scale = Vector2.ONE * BOARD_SCALE
	world.add_child(board)
	world.move_child(board, 0)
	board.setup(COLS, ROWS, NUM_COLORS, debug_seed)
	board.broke.connect(_on_broke)
	board.blocked.connect(_on_blocked)


func _show_title() -> void:
	state = State.TITLE
	board.input_enabled = false
	board.clear_preview()
	pause_button.visible = false
	Engine.time_scale = 1.0
	menus.show_title(best)
	music.play_title()


func _start_game() -> void:
	menus.hide_all()
	rules.reset()
	stamp_lock = 0.0
	now_view.cooldown = 0.0
	Engine.time_scale = 1.0
	_last_tick = -1
	in_fever = false
	_set_bg(GameSkin.c("bg"))
	combo_label.text = ""
	_new_board()
	queue = ShapeQueue.new(debug_seed)
	held = {}
	hold_used = false
	current = queue.pop()
	_refresh_pieces()
	board.input_enabled = true
	board.locked = false
	pause_button.visible = true
	state = State.PLAY
	sfx.play("start")
	music.play_game()
	_update_hud()


func _end_game() -> void:
	state = State.RESULT
	board.input_enabled = false
	board.clear_preview()
	pause_button.visible = false
	_break_combo()
	sfx.play("end")
	music.end_game()
	var score := rules.score
	var new_best := score > best and not _autoplay
	if new_best:
		best = score
		_save()
	var g: Array = rules.grade_counts
	await get_tree().create_timer(0.9).timeout
	if state != State.RESULT:
		return
	menus.show_result({
		"score": score, "new_best": new_best, "best": best, "max_combo": rules.max_combo,
		"grades": g.duplicate(), "time": int(rules.bonus_time_total), "biggest": rules.biggest,
	})
	if _autoplay:
		await get_tree().create_timer(1.5).timeout
		get_tree().quit()


func _pause() -> void:
	if state != State.PLAY:
		return
	state = State.PAUSED
	board.input_enabled = false
	board.clear_preview()
	Engine.time_scale = 1.0
	menus.show_panel("pause")
	music.set_paused(true)


func _resume() -> void:
	if state != State.PAUSED:
		return
	menus.hide_all()
	board.input_enabled = true
	state = State.PLAY
	music.set_paused(false)
	music.set_fever(in_fever)


func _to_title() -> void:
	_break_combo()
	_set_bg(GameSkin.c("bg"))
	combo_label.text = ""
	_new_board()
	_show_title()


# ---------------------------------------------------------------- 조각 / 홀드

func _refresh_pieces() -> void:
	board.set_piece(current["cells"])
	current_best_n = Bot.best_move(board.model, current["cells"])["count"]
	now_view.set_piece(current["cells"])
	var nexts := queue.peek(next_views.size())
	for i in next_views.size():
		next_views[i].set_piece(nexts[i]["cells"])
	hold_view.dimmed = hold_used
	hold_view.set_piece(held.get("cells", []))


func _do_hold() -> void:
	if state != State.PLAY or hold_used:
		return
	var from_queue := held.is_empty()
	if from_queue:
		held = current
		current = queue.pop()
	else:
		var tmp := held
		held = current
		current = tmp
	hold_used = true
	sfx.play("hold")
	_refresh_pieces()
	if from_queue:
		_slide_queue()
	else:
		now_view.slide_in(Vector2(0, -130))  # HOLD(위 칸)에서 꺼낸 모양은 위에서 내려온다
	hold_view.slide_in(Vector2(0, 130))


## 큐가 한 칸 당겨질 때: 모든 모양이 아래 칸 자리에서 위로 미끄러져 올라온다.
func _slide_queue() -> void:
	now_view.slide_in(Vector2(0, next_views[0].position.y - now_view.position.y))
	for i in next_views.size():
		var v: PieceView = next_views[i]
		var dy: float = 70.0 if i == next_views.size() - 1 else next_views[i + 1].position.y - v.position.y
		v.slide_in(Vector2(0, dy))


# ---------------------------------------------------------------- 파괴 처리 / 점수 / 콤보

func _on_broke(info: Dictionary) -> void:
	var n: int = info["count"]
	var r := rules.register_break(n, current_best_n)
	stamp_lock = GameRules.STAMP_COOLDOWN
	board.locked = true
	var grade: int = r["grade"]
	var tier: int = r["tier"]
	var anchor_pos: Vector2 = info["anchor_pos"]

	_juice(info, n, tier, grade)
	_grade_text(grade, anchor_pos)
	_float_text("+%d" % r["points"], anchor_pos + Vector2(0, 44), GameSkin.c("tiers")[tier], 34)
	var dt: float = r["time_delta"]
	if dt > 0.0:
		_float_text("+%ds" % int(dt), Vector2(560, 120), Color(0.4, 1.0, 0.6), 44)
		sfx.play("bonus")
		_pulse(time_label)
	elif dt < 0.0:
		_float_text("-%ds" % int(-dt), Vector2(560, 120), Color(1, 0.35, 0.35), 44)
	if grade == GameRules.Grade.MISS:
		_break_combo()

	current = queue.pop()
	hold_used = false
	_refresh_pieces()
	_slide_queue()
	_update_hud()


## 쿨다운 중에 찍으려 하면 NOW 칸을 살짝 흔들어 "아직"이라고 알려 준다.
func _on_blocked() -> void:
	sfx.play("tick", 0.6, -8.0)
	var t := now_view.create_tween()
	var x := now_view.position.x
	t.tween_property(now_view, "position:x", x + 8.0, 0.03)
	t.tween_property(now_view, "position:x", x - 8.0, 0.05)
	t.tween_property(now_view, "position:x", x, 0.03)


func _grade_text(grade: int, pos: Vector2) -> void:
	var font_size: int = [58, 50, 42, 44][grade]
	var text: String = GameRules.GRADE_NAMES[grade] + ("!" if grade == GameRules.Grade.PERFECT else "")
	_float_text(text, pos - Vector2(0, 10), GameSkin.c("grades")[grade], font_size)


func _pulse(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * 1.25
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _break_combo() -> void:
	var t := combo_label.create_tween()
	t.tween_property(combo_label, "modulate:a", 0.0, 0.25)
	if in_fever:
		in_fever = false
		_set_bg(GameSkin.c("bg"))
		music.set_fever(false)


# ---------------------------------------------------------------- 타격감

func _juice(info: Dictionary, n: int, tier: int, grade: int) -> void:
	var broken: Array = info["broken"]
	var power := 280.0 + tier * 110.0
	var amount := 4 + tier * 2
	if broken.size() > 35:
		amount = maxi(2, amount - 2)
	for b in broken:
		var col: Color = GameSkin.block(b["color"])
		fx.burst(b["pos"], col, amount, power)
		fx.flash_cell(b["pos"], Block.SIZE * BOARD_SCALE, col)
	fx.ring(info["anchor_pos"], 70.0 + n * 6.0 + tier * 40.0, GameSkin.c("ring"))

	if grade == GameRules.Grade.MISS:
		# 실수는 약하고 둔탁하게: 짧은 흔들림 + 낮은 소리 + 붉은 섬광
		trauma = minf(1.0, trauma + 0.25)
		sfx.play("break", 0.7, -6.0)
		sfx.play("miss")
		flash_rect.color = Color(1, 0.1, 0.1, 0.18)
		flash_rect.create_tween().tween_property(flash_rect, "color:a", 0.0, 0.3)
		return

	var perfect := grade == GameRules.Grade.PERFECT
	trauma = minf(1.0, trauma + 0.12 + n * 0.012 + tier * 0.08 + (0.1 if perfect else 0.0))
	if n >= 12 or tier >= 1 or perfect:
		_hitstop(0.025 + minf(n, 40) * 0.0012 + tier * 0.015)

	sfx.play("break", randf_range(0.9, 1.1) * (0.85 if n >= 15 else 1.0))
	sfx.play("pop", 1.0 + minf(rules.combo - 1, 24) * 0.055, -4.0)
	if perfect:
		sfx.play("perfect", 1.0 + minf(rules.combo, 12) * 0.03, -3.0)
	if n >= 15:
		sfx.play("big")
	if tier >= 2:
		_flash(0.1 + (tier - 2) * 0.08)
	if tier >= 3 and not in_fever:
		_enter_fever()
	_combo_pop(tier)


func _combo_pop(tier: int) -> void:
	if rules.combo < 2:
		combo_label.text = ""
		return
	combo_label.text = "%d COMBO" % rules.combo
	combo_label.add_theme_color_override("font_color", GameSkin.c("tiers")[tier])
	combo_label.scale = Vector2.ONE * (1.3 + tier * 0.15)
	var t := combo_label.create_tween()
	t.tween_property(combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _enter_fever() -> void:
	in_fever = true
	_set_bg(GameSkin.c("bg_fever"))
	music.set_fever(true)
	sfx.play("fever")
	_flash(0.45)
	_float_text("FEVER!", Vector2(360, 600), GameSkin.c("tiers")[3], 84)


func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _flash(alpha: float) -> void:
	flash_rect.color = Color(1, 1, 1, alpha)
	var t := flash_rect.create_tween()
	t.tween_property(flash_rect, "color:a", 0.0, 0.25)


func _set_bg(c: Color) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(bg_rect, "tint", c, 0.3)
	t.tween_property(top_panel, "tint", c, 0.3)


func _float_text(text: String, pos: Vector2, color: Color, font_size: int) -> void:
	var l := _label(text, font_size, pos - Vector2(200, font_size * 0.7), HORIZONTAL_ALIGNMENT_CENTER, 400)
	l.add_theme_color_override("font_color", color)
	hud.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 90, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- 프레임 처리 / 입력

func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 1.8)
		var s := 26.0 * trauma * trauma * (1.0 if shake_enabled else 0.0)
		world.position = Vector2(randf_range(-s, s), randf_range(-s, s))
	else:
		world.position = Vector2.ZERO

	if state != State.PLAY:
		return

	if rules.tick(delta):
		_break_combo()

	if stamp_lock > 0.0:
		stamp_lock = maxf(0.0, stamp_lock - delta)
		board.locked = stamp_lock > 0.0
		now_view.cooldown = stamp_lock / GameRules.STAMP_COOLDOWN

	var sec := int(ceil(rules.time_left))
	if rules.time_left <= 10.0 and rules.time_left > 0.0 and sec != _last_tick:
		_last_tick = sec
		sfx.play("tick")

	if _autoplay:
		_autoplay_timer -= delta
		if _autoplay_timer <= 0.0 and stamp_lock <= 0.0:
			_autoplay_timer = randf_range(0.35, 0.9)
			var mv := Bot.best_move(board.model, current["cells"])
			board.place_at(mv["cell"])

	if rules.is_over():
		rules.time_left = 0.0
		_update_hud()
		_end_game()
		return
	_update_hud()


## _unhandled_input이 아니라 _input에서 받는다: 포커스를 가진 버튼 등 GUI가 Space를 먼저 먹지 않게.
## physical_keycode로 비교해서 한/영 상태나 자판 배열과 상관없이 같은 자리 키가 동작한다.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		match k:
			KEY_SPACE, KEY_SHIFT, KEY_C:
				if state == State.PLAY:
					_do_hold()
					get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_P:
				if state == State.PLAY:
					_pause()
				elif menus.is_open():
					menus.back()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_do_hold()


# ---------------------------------------------------------------- HUD

func _update_hud() -> void:
	var time_left := rules.time_left
	var combo := rules.combo
	score_label.text = str(rules.score)
	best_label.text = I18n.t("BEST_FMT") % best
	time_label.text = "%.1f" % maxf(time_left, 0.0)
	# 남은 시간 60초 → 30초 → 10초를 기준점으로 색이 바뀐다.
	# 숫자: 노랑(60) → 주황(30) → 빨강(10 이하) / 막대: 하늘색(60) → 보라(30) → 빨강(10 이하)
	var danger := snappedf(_time_danger_for(time_left), 0.02)
	if danger != _time_danger:
		_time_danger = danger
		time_label.add_theme_color_override("font_color", _danger_color(GameSkin.c("time_text"), danger))
		time_label.add_theme_color_override("font_outline_color", Color(_danger_color(GameSkin.c("time_glow"), danger), 0.55))
	target_label.text = I18n.t("TARGET_FMT") % rules.time_target()
	time_bar.size.x = 640.0 * clampf(time_left / GameRules.GAME_TIME, 0.0, 1.0)
	time_bar.color = _danger_color(GameSkin.c("time"), _time_danger)
	var k := clampf(rules.combo_timer / rules.combo_window, 0.0, 1.0) if combo > 0 else 0.0
	combo_bar.size.x = 320.0 * k
	combo_bar.position.x = 360.0 - combo_bar.size.x / 2.0
	combo_bar.color = GameSkin.c("tiers")[GameRules.tier_for(combo)]
	if combo >= 2:
		combo_label.modulate.a = 1.0


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 1
	add_child(hud)

	# 보드 위쪽에서 떨어지는 새 블록을 가리는 상단 패널
	top_panel = _backdrop(Vector2(720, BOARD_POS.y - 2.0))
	hud.add_child(top_panel)

	var gray := Color(1, 1, 1, 0.5)
	# 점수(왼쪽)와 시간(오른쪽)은 서로 다른 색으로 나눠 한눈에 구분되게 한다.
	var l := _label("SCORE", 22, Vector2(40, 26))
	l.modulate = gray
	_tint(l, "score")
	hud.add_child(l)
	score_label = _label("0", 56, Vector2(40, 50), HORIZONTAL_ALIGNMENT_LEFT, 400)
	_tint(score_label, "score")
	hud.add_child(score_label)
	best_label = _label("", 20, Vector2(40, 128))
	best_label.modulate = gray
	hud.add_child(best_label)
	l = _label("TIME", 22, Vector2(380, 26), HORIZONTAL_ALIGNMENT_RIGHT)
	l.modulate = gray
	_tint(l, "time")
	hud.add_child(l)
	time_label = _label("60.0", 56, Vector2(380, 50), HORIZONTAL_ALIGNMENT_RIGHT)
	_tint(time_label, "time")
	hud.add_child(time_label)
	target_label = _label("", 20, Vector2(380, 128), HORIZONTAL_ALIGNMENT_RIGHT)
	target_label.add_theme_color_override("font_color", Color(GameSkin.c("time_text"), 0.85))
	hud.add_child(target_label)

	hud.add_child(_rect(Vector2(40, 168), Vector2(640, 12), GameSkin.c("track")))
	time_bar = _rect(Vector2(40, 168), Vector2(640, 12), GameSkin.c("time"))
	hud.add_child(time_bar)

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.position = Vector2(318, 40)
	pause_button.size = Vector2(84, 84)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.add_theme_font_size_override("font_size", 34)
	pause_button.add_theme_color_override("font_color", GameSkin.c("text"))
	pause_button.add_theme_color_override("font_hover_color", GameSkin.c("text"))
	for k in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(GameSkin.c("text"), 0.08 if k == "normal" else 0.18)
		box.set_corner_radius_all(42)
		box.border_color = GameSkin.c("panel_border")
		box.set_border_width_all(2)
		pause_button.add_theme_stylebox_override(k, box)
	pause_button.pressed.connect(_pause)
	pause_button.visible = false
	hud.add_child(pause_button)

	combo_label = _label("", 50, Vector2(0, BOARD_POS.y - 100.0), HORIZONTAL_ALIGNMENT_CENTER, 720)
	combo_label.pivot_offset = combo_label.size / 2.0
	hud.add_child(combo_label)
	combo_bar = _rect(Vector2(200, BOARD_POS.y - 28.0), Vector2(320, 6), Color.WHITE)
	hud.add_child(combo_bar)

	# 오른쪽 세로 줄: HOLD / NOW / NEXT1~4 — 다음 모양이 아래에서 위(NOW)로 올라온다.
	var y := BOARD_POS.y
	hold_view = _piece_view("HOLD", Vector2(SIDE_X, y), Vector2(SIDE_W, 118), 20.0, false)
	hold_view.hint = "HOLD_HINT"
	hold_view.title_size = 18
	hold_view.pressed.connect(_do_hold)
	y += 128.0
	now_view = _piece_view("NOW", Vector2(SIDE_X, y), Vector2(SIDE_W, 170), 30.0, true)
	y += 178.0
	var next_title := _label("NEXT", 18, Vector2(SIDE_X + 10.0, y))
	next_title.modulate = Color(1, 1, 1, 0.55)
	hud.add_child(next_title)
	y += 28.0
	next_views = []
	for i in NEXT_COUNT:
		var h := 104.0 if i == 0 else 56.0
		var v := _piece_view("", Vector2(SIDE_X, y), Vector2(SIDE_W, h), 20.0 if i == 0 else 11.0, false)
		v.modulate.a = 1.0 - 0.15 * i
		next_views.append(v)
		y += h + 6.0
	var hint := _label("FOOTER", 17, Vector2(0, 1240), HORIZONTAL_ALIGNMENT_CENTER, 720)
	hint.modulate = Color(1, 1, 1, 0.35)
	hud.add_child(hint)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 4
	add_child(flash_layer)
	flash_rect = _rect(Vector2.ZERO, Vector2(720, 1280), Color(1, 1, 1, 0))
	flash_layer.add_child(flash_rect)


func _build_menus() -> void:
	menus = Menus.new()
	add_child(menus)
	menus.sfx = sfx
	menus.set_settings(volume, music_volume, shake_enabled)
	menus.start_pressed.connect(_start_game)
	menus.restart_pressed.connect(_start_game)
	menus.resume_pressed.connect(_resume)
	menus.title_pressed.connect(_to_title)
	menus.settings_changed.connect(func(v: float, m: float, s: bool):
		volume = v
		music_volume = m
		shake_enabled = s
		_apply_settings()
		_save()
		sfx.play("pop"))
	menus.title_slammed.connect(func():
		sfx.play("big", 1.1)
		sfx.play("perfect", 0.8, -6.0))
	menus.language_changed.connect(func(code: String):
		lang = code
		I18n.set_lang(code)
		_save()
		_update_hud()
		sfx.play("pop"))


## 효과음(SFX)과 음악(Music) 버스를 만든다. 둘 다 Master로 보낸다.
func _ensure_buses() -> void:
	for name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(name) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")


func _apply_settings() -> void:
	for pair in [["SFX", volume], ["Music", music_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		var v: float = pair[1]
		AudioServer.set_bus_mute(bus, v <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.001)))


func _piece_view(title: String, pos: Vector2, size: Vector2, cell_px: float, highlight: bool) -> PieceView:
	var v := PieceView.new()
	v.title = title
	v.position = pos
	v.size = size
	v.cell_px = cell_px
	v.highlight = highlight
	hud.add_child(v)
	return v


func _label(text: String, font_size: int, pos: Vector2, align := HORIZONTAL_ALIGNMENT_LEFT, width := 300.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, font_size * 1.4)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", GameSkin.c("text"))
	l.add_theme_color_override("font_outline_color", GameSkin.c("outline"))
	l.add_theme_constant_override("outline_size", int(maxi(4, font_size / 7) * GameSkin.c("outline_scale")))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 남은 시간 → 위험도(0~1). 60초 이상 0, 30초 0.5, 10초 이하 1, 그 사이는 고르게 이어진다.
static func _time_danger_for(t: float) -> float:
	if t >= 60.0:
		return 0.0
	if t >= 30.0:
		return (60.0 - t) / 60.0
	return clampf(0.5 + (30.0 - t) / 40.0, 0.5, 1.0)


## 위험도만큼 빨강 쪽으로 옮긴 색. 그냥 섞으면 중간이 탁해지므로 색상환을 따라 가까운 쪽으로 돌아 빨강에 닿는다.
## (노랑은 주황을 거쳐, 하늘색은 파랑·보라를 거쳐 빨강)
func _danger_color(base: Color, danger: float) -> Color:
	if danger <= 0.0:
		return base
	var red_h := 0.0 if base.h < 0.5 else 1.0
	return Color.from_hsv(lerpf(base.h, red_h, danger), lerpf(base.s, 0.85, danger), 1.0)


## 점수/시간 글자에 각자의 색과 빛(외곽선)을 입힌다.
func _tint(l: Label, which: String) -> void:
	l.add_theme_color_override("font_color", GameSkin.c("score" if which == "score" else "time_text"))
	l.add_theme_color_override("font_outline_color", GameSkin.c(which + "_glow"))


func _backdrop(size: Vector2) -> Backdrop:
	var b := Backdrop.new()
	b.size = size
	b.tint = GameSkin.c("bg")
	return b


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---------------------------------------------------------------- 저장

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = int(cfg.get_value("score", "best", 0))
		volume = float(cfg.get_value("settings", "volume", 0.8))
		music_volume = float(cfg.get_value("settings", "music", 0.7))
		shake_enabled = bool(cfg.get_value("settings", "shake", true))
		lang = str(cfg.get_value("settings", "lang", I18n.DEFAULT_LANG))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "music", music_volume)
	cfg.set_value("settings", "shake", shake_enabled)
	cfg.set_value("settings", "lang", lang)
	cfg.save(SAVE_PATH)
