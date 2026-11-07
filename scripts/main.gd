extends Node2D
## 게임 흐름(타이틀 → 플레이 → 결과), 점수/콤보/시간, HUD, 타격감 연출을 담당한다.

enum State { TITLE, PLAY, PAUSED, RESULT }

const COLS := 8
const ROWS := 9
const NUM_COLORS := 5
const BOARD_POS := Vector2(40, 270)
const BG_NORMAL := Color(0.07, 0.07, 0.11)
const BG_FEVER := Color(0.22, 0.07, 0.24)
const SAVE_PATH := "user://save.cfg"
## 콤보 단계 색 (단계 구분은 GameRules.TIER_START)
const TIER_COLORS: Array = [Color(1, 1, 1), Color(1.0, 0.85, 0.35), Color(1.0, 0.5, 0.3), Color(1.0, 0.4, 0.9)]
const GRADE_COLORS: Array = [Color(1.0, 0.9, 0.3), Color(0.45, 0.95, 1.0), Color(0.6, 1.0, 0.6), Color(1.0, 0.3, 0.3)]

var state := State.TITLE
var rules := GameRules.new()
var best := 0
## 현재 모양으로 이 보드에서 가능한 최대 파괴 수(판정 기준)
var current_best_n := 0
var trauma := 0.0
var shake_enabled := true
var volume := 0.8
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
var hud: CanvasLayer
var bg_rect: ColorRect
var top_panel: ColorRect
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


func _ready() -> void:
	randomize()
	_load_save()

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	bg_rect = _rect(Vector2.ZERO, Vector2(720, 1280), BG_NORMAL)
	bg_layer.add_child(bg_rect)

	world = Node2D.new()
	add_child(world)
	fx = Fx.new()
	fx.z_index = 20
	world.add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)

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
	world.add_child(board)
	world.move_child(board, 0)
	board.setup(COLS, ROWS, NUM_COLORS)
	board.broke.connect(_on_broke)
	board.blocked.connect(_on_blocked)


func _show_title() -> void:
	state = State.TITLE
	board.input_enabled = false
	board.clear_preview()
	pause_button.visible = false
	Engine.time_scale = 1.0
	menus.show_title(best)


func _start_game() -> void:
	menus.hide_all()
	rules.reset()
	stamp_lock = 0.0
	now_view.cooldown = 0.0
	Engine.time_scale = 1.0
	_last_tick = -1
	in_fever = false
	_set_bg(BG_NORMAL)
	combo_label.text = ""
	_new_board()
	queue = ShapeQueue.new()
	held = {}
	hold_used = false
	current = queue.pop()
	_refresh_pieces()
	board.input_enabled = true
	board.locked = false
	pause_button.visible = true
	state = State.PLAY
	sfx.play("start")
	_update_hud()


func _end_game() -> void:
	state = State.RESULT
	board.input_enabled = false
	board.clear_preview()
	pause_button.visible = false
	_break_combo()
	sfx.play("end")
	var score := rules.score
	var new_best := score > best and not _autoplay
	if new_best:
		best = score
		_save()
	var g: Array = rules.grade_counts
	await get_tree().create_timer(0.9).timeout
	if state != State.RESULT:
		return
	menus.show_result("TIME UP!", score, "NEW BEST!" if new_best else "BEST  %d" % best,
		"MAX COMBO   %d\nPERFECT %d  GREAT %d  GOOD %d  MISS %d\nTIME EARNED   +%ds\nBIGGEST BREAK   %d" % [
		rules.max_combo, g[0], g[1], g[2], g[3], int(rules.bonus_time_total), rules.biggest])
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


func _resume() -> void:
	if state != State.PAUSED:
		return
	menus.hide_all()
	board.input_enabled = true
	state = State.PLAY


func _to_title() -> void:
	_break_combo()
	_set_bg(BG_NORMAL)
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
	if held.is_empty():
		held = current
		current = queue.pop()
	else:
		var tmp := held
		held = current
		current = tmp
	hold_used = true
	sfx.play("hold")
	_refresh_pieces()


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
	_float_text("+%d" % r["points"], anchor_pos + Vector2(0, 44), TIER_COLORS[tier], 34)
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
	_float_text(text, pos - Vector2(0, 10), GRADE_COLORS[grade], font_size)


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
		_set_bg(BG_NORMAL)


# ---------------------------------------------------------------- 타격감

func _juice(info: Dictionary, n: int, tier: int, grade: int) -> void:
	var broken: Array = info["broken"]
	var power := 280.0 + tier * 110.0
	var amount := 4 + tier * 2
	if broken.size() > 35:
		amount = maxi(2, amount - 2)
	for b in broken:
		var col: Color = Block.COLORS[b["color"]]
		fx.burst(b["pos"], col, amount, power)
		fx.flash_cell(b["pos"], Block.SIZE, col)
	fx.ring(info["anchor_pos"], 70.0 + n * 6.0 + tier * 40.0, Color(1, 1, 1, 0.9))

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
	combo_label.modulate = TIER_COLORS[tier]
	combo_label.scale = Vector2.ONE * (1.3 + tier * 0.15)
	var t := combo_label.create_tween()
	t.tween_property(combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _enter_fever() -> void:
	in_fever = true
	_set_bg(BG_FEVER)
	sfx.play("fever")
	_flash(0.45)
	_float_text("FEVER!", Vector2(360, 600), TIER_COLORS[3], 84)


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
	t.tween_property(bg_rect, "color", c, 0.3)
	t.tween_property(top_panel, "color", c, 0.3)


func _float_text(text: String, pos: Vector2, color: Color, font_size: int) -> void:
	var l := _label(text, font_size, pos - Vector2(200, font_size * 0.7), HORIZONTAL_ALIGNMENT_CENTER, 400)
	l.modulate = color
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_SHIFT, KEY_C:
				if state == State.PLAY:
					_do_hold()
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
	best_label.text = "BEST %d" % best
	time_label.text = "%.1f" % maxf(time_left, 0.0)
	time_label.modulate = Color(1, 0.35, 0.35) if time_left <= 10.0 else Color.WHITE
	target_label.text = "+1s AT %d PTS" % rules.time_target()
	time_bar.size.x = 640.0 * clampf(time_left / GameRules.GAME_TIME, 0.0, 1.0)
	time_bar.color = Color(1, 0.35, 0.35) if time_left <= 10.0 else Color(0.4, 0.9, 0.6)
	var k := clampf(rules.combo_timer / rules.combo_window, 0.0, 1.0) if combo > 0 else 0.0
	combo_bar.size.x = 320.0 * k
	combo_bar.position.x = 360.0 - combo_bar.size.x / 2.0
	combo_bar.color = TIER_COLORS[GameRules.tier_for(combo)]
	if combo >= 2:
		combo_label.modulate.a = 1.0


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 1
	add_child(hud)

	# 보드 위쪽에서 떨어지는 새 블록을 가리는 상단 패널
	top_panel = _rect(Vector2.ZERO, Vector2(720, 256), BG_NORMAL)
	hud.add_child(top_panel)

	var gray := Color(1, 1, 1, 0.5)
	var l := _label("SCORE", 22, Vector2(40, 26))
	l.modulate = gray
	hud.add_child(l)
	score_label = _label("0", 56, Vector2(40, 50), HORIZONTAL_ALIGNMENT_LEFT, 400)
	hud.add_child(score_label)
	best_label = _label("BEST 0", 20, Vector2(40, 128))
	best_label.modulate = gray
	hud.add_child(best_label)
	l = _label("TIME", 22, Vector2(380, 26), HORIZONTAL_ALIGNMENT_RIGHT)
	l.modulate = gray
	hud.add_child(l)
	time_label = _label("60.0", 56, Vector2(380, 50), HORIZONTAL_ALIGNMENT_RIGHT)
	hud.add_child(time_label)
	target_label = _label("", 20, Vector2(380, 128), HORIZONTAL_ALIGNMENT_RIGHT)
	target_label.modulate = Color(0.4, 0.9, 0.6, 0.8)
	hud.add_child(target_label)

	hud.add_child(_rect(Vector2(40, 168), Vector2(640, 12), Color(1, 1, 1, 0.08)))
	time_bar = _rect(Vector2(40, 168), Vector2(640, 12), Color(0.4, 0.9, 0.6))
	hud.add_child(time_bar)

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.position = Vector2(318, 40)
	pause_button.size = Vector2(84, 84)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.add_theme_font_size_override("font_size", 34)
	for k in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.08 if k == "normal" else 0.18)
		box.set_corner_radius_all(42)
		pause_button.add_theme_stylebox_override(k, box)
	pause_button.pressed.connect(_pause)
	pause_button.visible = false
	hud.add_child(pause_button)

	combo_label = _label("", 50, Vector2(0, 182), HORIZONTAL_ALIGNMENT_CENTER, 720)
	combo_label.pivot_offset = combo_label.size / 2.0
	hud.add_child(combo_label)
	combo_bar = _rect(Vector2(200, 244), Vector2(320, 6), Color.WHITE)
	hud.add_child(combo_bar)

	hold_view = _piece_view("HOLD", Vector2(40, 1022), Vector2(170, 200), 30.0, false)
	hold_view.pressed.connect(_do_hold)
	now_view = _piece_view("NOW", Vector2(230, 1012), Vector2(260, 220), 42.0, true)
	next_views = [
		_piece_view("NEXT", Vector2(510, 1022), Vector2(170, 96), 18.0, false),
		_piece_view("", Vector2(510, 1126), Vector2(170, 96), 18.0, false),
	]
	var hint := _label("HOLD: right-click / Space / tap HOLD     PAUSE: ESC", 17, Vector2(0, 1240), HORIZONTAL_ALIGNMENT_CENTER, 720)
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
	menus.set_settings(volume, shake_enabled)
	menus.start_pressed.connect(_start_game)
	menus.restart_pressed.connect(_start_game)
	menus.resume_pressed.connect(_resume)
	menus.title_pressed.connect(_to_title)
	menus.settings_changed.connect(func(v: float, s: bool):
		volume = v
		shake_enabled = s
		_apply_settings()
		_save()
		sfx.play("pop"))


func _apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))


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
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
		shake_enabled = bool(cfg.get_value("settings", "shake", true))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "shake", shake_enabled)
	cfg.save(SAVE_PATH)
