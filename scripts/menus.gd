class_name Menus
extends CanvasLayer
## 타이틀 / 플레이 방법 / 설정 / 일시정지 / 결과 화면. 버튼을 누르면 신호만 보내고, 실제 흐름은 main.gd가 처리한다.

signal start_pressed
signal resume_pressed
signal restart_pressed
signal title_pressed
signal settings_changed(volume: float, music: float, shake: bool)
signal language_changed(code: String)
## 타이틀 로고의 STAMP가 쾅 찍힌 순간(효과음은 main이 낸다)
signal title_slammed

const W := 720.0
const H := 1280.0
const BTN_W := 420.0
const BTN_H := 92.0

var volume := 0.8
var shake := true
var music := 0.7

var _panels: Dictionary = {}
var _settings_back := "title"
var _best_label: Label
var _result_title: Label
var _result_score: Label
var _result_best: Label
var _result_panel: Control
## 결과 연출에서 차례로 나타나는 줄들: {root, labels, targets, fmts}
var _result_rows: Array = []
var _result_buttons: Array = []
var _result_data: Dictionary = {}
## 연출 회차. 건너뛰거나 다시 열면 바뀌어서 진행 중이던 연출이 멈춘다. 0이면 연출 중이 아님.
var _result_run := 0
var _result_serial := 0
## main이 넣어 준다(결과 숫자 올라가는 소리 등)
var sfx: Sfx
var _volume_label: Label
var _volume_slider: HSlider
var _music_label: Label
var _music_slider: HSlider
var _shake_button: Button
var _quit_button: Button
var _lang_button: Button
var _logo: TitleLogo
## 로고 연출이 끝난 뒤 차례로 나타나는 타이틀 요소들
var _title_items: Array = []
var _best := 0


var ACCENT: Color


func _ready() -> void:
	ACCENT = GameSkin.c("accent")
	layer = 5
	_build_title()
	_build_howto()
	_build_settings()
	_build_pause()
	_build_result()
	hide_all()


# ---------------------------------------------------------------- 표시 전환

func hide_all() -> void:
	for p in _panels.values():
		p.visible = false


func is_open() -> bool:
	for p in _panels.values():
		if p.visible:
			return true
	return false


func current() -> String:
	for k in _panels:
		if _panels[k].visible:
			return k
	return ""


func show_panel(name: String) -> void:
	hide_all()
	var p: Control = _panels[name]
	p.visible = true
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.18)
	# 키보드/패드로도 고를 수 있게 첫 버튼에 포커스
	var first := _first_button(p)
	if first:
		first.grab_focus.call_deferred()


func show_title(best: int) -> void:
	_best = best
	_refresh_best()
	show_panel("title")
	_play_title_intro()


## data: score, new_best(bool), best, max_combo, grades[4], time, biggest
func show_result(data: Dictionary) -> void:
	_result_data = data
	show_panel("result")
	_result_serial += 1
	_result_run = _result_serial
	_play_result(_result_run)


func set_settings(v: float, m: float, s: bool) -> void:
	volume = v
	music = m
	shake = s
	_volume_slider.set_value_no_signal(v * 100.0)
	_music_slider.set_value_no_signal(m * 100.0)
	_refresh_settings()


## ESC / 뒤로 가기: 열린 화면에 맞는 "뒤로" 동작
func back() -> void:
	match current():
		"howto":
			show_panel("title")
		"settings":
			show_panel(_settings_back)
		"pause":
			resume_pressed.emit()


# ---------------------------------------------------------------- 화면 구성

func _build_title() -> void:
	var p := _panel("title", 1.0)
	p.add_child(TitleBackdrop.new())
	_logo = TitleLogo.new()
	_logo.position = Vector2(0, 150)
	_logo.size = Vector2(W, 400)
	_logo.slammed.connect(_on_logo_slammed)
	p.add_child(_logo)
	var sub := _label("TAGLINE", 26, Vector2(0, 540), W)
	p.add_child(sub)
	_best_label = _label("", 30, Vector2(0, 586), W)
	_best_label.add_theme_color_override("font_color", ACCENT)
	p.add_child(_best_label)
	var y := 668.0
	var start := _button("START", y, func(): start_pressed.emit(), true)
	p.add_child(start)
	var howto := _button("HOW_TO_PLAY", y + 112, func(): show_panel("howto"))
	p.add_child(howto)
	var settings := _button("SETTINGS", y + 224, func(): _open_settings("title"))
	p.add_child(settings)
	_quit_button = _button("QUIT", y + 336, func(): get_tree().quit())
	# 웹에서는 창을 닫을 수 없으므로 숨긴다.
	_quit_button.visible = not OS.has_feature("web")
	p.add_child(_quit_button)
	_title_items = [sub, _best_label, start, howto, settings, _quit_button]


## 로고 등장 → 끝나면 문구와 버튼이 아래에서 살짝 올라오며 차례로 나타난다.
## 연출 중에도 버튼은 눌린다(바로 시작하고 싶은 사람을 막지 않게).
func _play_title_intro() -> void:
	_logo.play_intro()
	var base := _logo.intro_length() + 0.1
	for i in _title_items.size():
		var c: Control = _title_items[i]
		var target := 0.7 if i == 0 else 1.0
		var y := c.position.y
		c.modulate.a = 0.0
		c.position.y = y + 24.0
		var t := c.create_tween().set_parallel()
		t.tween_property(c, "modulate:a", target, 0.25).set_delay(base + i * 0.06)
		t.tween_property(c, "position:y", y, 0.3).set_delay(base + i * 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_logo_slammed() -> void:
	title_slammed.emit()
	_shake(14.0)


## 메뉴 화면 전체를 짧게 흔든다(설정에서 흔들림을 끄면 생략).
func _shake(power: float) -> void:
	if not shake:
		return
	var t := create_tween()
	for i in 6:
		var k := 1.0 - i / 6.0
		t.tween_property(self, "offset", Vector2(randf_range(-power, power), randf_range(-power, power) * 0.7) * k, 0.03)
	t.tween_property(self, "offset", Vector2.ZERO, 0.04)


func _build_howto() -> void:
	var p := _panel("howto", 0.92)
	p.add_child(_heading("HOW_TO_PLAY"))
	var body := _label("HOWTO_BODY", 27, Vector2(0, 280), W)
	body.size.y = 720
	p.add_child(body)
	p.add_child(_button("BACK", 1080, func(): show_panel("title"), true))


func _build_settings() -> void:
	var p := _panel("settings", 0.92)
	p.add_child(_heading("SETTINGS"))
	_volume_label = _label("", 34, Vector2(0, 330), W)
	p.add_child(_volume_label)
	_volume_slider = _slider(390, func(v: float):
		volume = v / 100.0
		_refresh_settings()
		settings_changed.emit(volume, music, shake))
	p.add_child(_volume_slider)
	_music_label = _label("", 34, Vector2(0, 480), W)
	p.add_child(_music_label)
	_music_slider = _slider(540, func(v: float):
		music = v / 100.0
		_refresh_settings()
		settings_changed.emit(volume, music, shake))
	p.add_child(_music_slider)

	_shake_button = _button("", 660, func():
		shake = not shake
		_refresh_settings()
		settings_changed.emit(volume, music, shake))
	p.add_child(_shake_button)
	_lang_button = _button("", 772, func():
		language_changed.emit(I18n.next_lang())
		_refresh_settings())
	p.add_child(_lang_button)
	p.add_child(_button("BACK", 1080, func(): show_panel(_settings_back), true))
	_refresh_settings()


func _slider(y: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.position = Vector2(150, y)
	s.size = Vector2(420, 60)
	s.add_theme_icon_override("grabber", _dot(30, GameSkin.c("text")))
	s.add_theme_icon_override("grabber_highlight", _dot(34, ACCENT))
	var track := StyleBoxFlat.new()
	track.bg_color = GameSkin.c("track")
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	s.add_theme_stylebox_override("slider", track)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = ACCENT
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)
	s.value_changed.connect(on_change)
	return s


func _build_pause() -> void:
	var p := _panel("pause", 0.97)
	p.add_child(_heading("PAUSED"))
	var y := 440.0
	p.add_child(_button("RESUME", y, func(): resume_pressed.emit(), true))
	p.add_child(_button("RESTART", y + 112, func(): restart_pressed.emit()))
	p.add_child(_button("SETTINGS", y + 224, func(): _open_settings("pause")))
	p.add_child(_button("TITLE", y + 336, func(): title_pressed.emit()))


func _build_result() -> void:
	var p := _panel("result", 0.86)
	_result_panel = p
	# 연출 중 화면(버튼 말고)을 누르면 끝 상태로 건너뛴다.
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and _result_run > 0:
			_finish_result())
	_result_title = _heading("TIME_UP")
	_result_title.position.y = 130
	p.add_child(_result_title)
	var l := _label("SCORE", 28, Vector2(0, 262), W)
	l.modulate.a = 0.6
	l.add_theme_color_override("font_color", GameSkin.c("score"))
	p.add_child(l)
	_result_score = _label("0", 100, Vector2(0, 296), W)
	_result_score.add_theme_color_override("font_color", GameSkin.c("score"))
	_result_score.add_theme_color_override("font_outline_color", GameSkin.c("score_glow"))
	p.add_child(_result_score)
	_result_best = _label("", 34, Vector2(0, 438), W)
	_result_best.add_theme_color_override("font_color", ACCENT)
	p.add_child(_result_best)

	var g: Array = GameSkin.c("grades")
	_result_rows = [
		_result_row(p, 528, "R_MAX_COMBO", ["%d"]),
		_grade_row(p, 606, g),
		_result_row(p, 716, "R_TIME", ["SEC_FMT"]),
		_result_row(p, 794, "R_BIGGEST", ["COUNT_FMT"]),
	]
	var retry := _button("RETRY", 930, func(): restart_pressed.emit(), true)
	var title := _button("TITLE", 1042, func(): title_pressed.emit())
	p.add_child(retry)
	p.add_child(title)
	_result_buttons = [retry, title]


func _row_box(p: Control, y: float, h: float) -> Panel:
	var box := Panel.new()
	box.position = Vector2(110, y)
	box.size = Vector2(500, h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameSkin.c("panel")
	sb.border_color = GameSkin.c("panel_border")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	box.add_theme_stylebox_override("panel", sb)
	p.add_child(box)
	return box


## 왼쪽에 이름, 오른쪽에 올라가는 숫자 하나.
func _result_row(p: Control, y: float, key: String, fmts: Array) -> Dictionary:
	var box := _row_box(p, y, 66)
	var name := _label(key, 28, Vector2(28, 12), 260)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.modulate.a = 0.75
	box.add_child(name)
	var v := _label("", 34, Vector2(200, 8), 272)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(v)
	return {"root": box, "labels": [v], "fmts": fmts, "targets": [0]}


## 판정 네 칸: 위에 판정 이름(색), 아래에 개수.
func _grade_row(p: Control, y: float, colors: Array) -> Dictionary:
	var box := _row_box(p, y, 96)
	var labels: Array = []
	for i in 4:
		var name := _label(GameRules.GRADE_NAMES[i], 18, Vector2(i * 125, 10), 125)
		name.add_theme_color_override("font_color", colors[i])
		box.add_child(name)
		var v := _label("", 34, Vector2(i * 125, 38), 125)
		v.add_theme_color_override("font_color", colors[i])
		box.add_child(v)
		labels.append(v)
	return {"root": box, "labels": labels, "fmts": ["%d", "%d", "%d", "%d"], "targets": [0, 0, 0, 0]}


## 결과 연출: 제목 → 점수가 띠리리릭 올라가며 쾅 → 최고 기록 → 아래 줄이 하나씩 나타나며 숫자 올라감 → 버튼.
func _play_result(run: int) -> void:
	var d := _result_data
	_result_rows[0]["targets"] = [d["max_combo"]]
	_result_rows[1]["targets"] = d["grades"]
	_result_rows[2]["targets"] = [d["time"]]
	_result_rows[3]["targets"] = [d["biggest"]]
	_result_score.text = "0"
	_result_best.text = ""
	for c in [_result_title, _result_score, _result_best]:
		c.modulate.a = 0.0
	for r in _result_rows:
		r["root"].modulate.a = 0.0
		for i in r["labels"].size():
			r["labels"][i].text = _fmt(r["fmts"][i], 0)
	for b in _result_buttons:
		b.modulate.a = 0.0

	# 제목이 크게 나타나며 내려앉는다
	_pop_in(_result_title, 1.6, 0.22)
	_play("pop", 0.8)
	if not await _wait(0.35, run):
		return
	# 점수: 클수록 조금 더 오래 올라간다
	_result_score.modulate.a = 1.0
	var score: int = d["score"]
	var dur := clampf(0.7 + score / 60000.0, 0.7, 1.6)
	if not await _count([_result_score], [score], ["%d"], dur, run):
		return
	_punch(_result_score, 1.25)
	_play("big", 1.2)
	if not await _wait(0.25, run):
		return
	if d["new_best"]:
		_result_best.text = I18n.t("NEW_BEST")
		_pop_in(_result_best, 2.2, 0.14)
		_play("perfect")
		_shake(10.0)
	else:
		_result_best.text = I18n.t("BEST_FMT") % d["best"]
		_pop_in(_result_best, 1.0, 0.2)
	if not await _wait(0.3, run):
		return
	# 아래 줄들이 하나씩
	for i in _result_rows.size():
		var r: Dictionary = _result_rows[i]
		_slide_in(r["root"])
		_play("pop", 1.0 + i * 0.12, -4.0)
		if not await _wait(0.12, run):
			return
		if not await _count(r["labels"], r["targets"], r["fmts"], 0.4, run):
			return
		if not await _wait(0.1, run):
			return
	for i in _result_buttons.size():
		_slide_in(_result_buttons[i], i * 0.07)
	_result_run = 0  # 연출 끝(이후 클릭은 건너뛰기가 아님)


## 화면을 누르면: 진행 중인 연출을 멈추고 모든 값을 끝 상태로 보여 준다.
func _finish_result() -> void:
	_result_run = 0
	var d := _result_data
	_result_score.text = str(d["score"])
	_result_best.text = I18n.t("NEW_BEST") if d["new_best"] else I18n.t("BEST_FMT") % d["best"]
	for c in [_result_title, _result_score, _result_best]:
		c.modulate.a = 1.0
		c.scale = Vector2.ONE
	for r in _result_rows:
		r["root"].modulate.a = 1.0
		for i in r["labels"].size():
			r["labels"][i].text = _fmt(r["fmts"][i], r["targets"][i])
	for b in _result_buttons:
		b.modulate.a = 1.0


func _fmt(f: String, v: int) -> String:
	return (f if f.begins_with("%") else I18n.t(f)) % v


## 숫자 여러 개를 같은 시간 동안 0에서 목표까지 올린다(처음엔 빠르게, 끝에서 천천히).
## 올라가는 동안 틱 소리가 점점 높아진다("띠리리릭").
func _count(labels: Array, targets: Array, fmts: Array, dur: float, run: int) -> bool:
	var has_value := false
	for v in targets:
		has_value = has_value or v > 0
	var t := 0.0
	var last_tick := -1.0
	while has_value and t < dur:
		await get_tree().process_frame
		if run != _result_run:
			return false
		t += get_process_delta_time()
		var e := 1.0 - pow(1.0 - clampf(t / dur, 0.0, 1.0), 3.0)
		for i in labels.size():
			labels[i].text = _fmt(fmts[i], int(round(targets[i] * e)))
		if t - last_tick >= 0.045:
			last_tick = t
			_play("tick", 0.85 + 0.9 * t / dur, -5.0)
	for i in labels.size():
		labels[i].text = _fmt(fmts[i], targets[i])
	return run == _result_run


func _wait(sec: float, run: int) -> bool:
	await get_tree().create_timer(sec).timeout
	return run == _result_run


func _play(sound: String, pitch := 1.0, db := 0.0) -> void:
	if sfx:
		sfx.play(sound, pitch, db)


## 크게(from_scale) 시작해 제자리 크기로 내려앉으며 나타난다.
func _pop_in(c: Control, from_scale: float, dur: float) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * from_scale
	c.modulate.a = 0.0
	var slam := from_scale >= 1.5
	var t := c.create_tween().set_parallel()
	t.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_QUAD if slam else Tween.TRANS_BACK).set_ease(Tween.EASE_IN if slam else Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, dur * 0.6)


func _punch(c: Control, s: float) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * s
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _slide_in(c: Control, delay := 0.0) -> void:
	var y := c.position.y
	c.position.y = y + 28.0
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel()
	t.tween_property(c, "position:y", y, 0.22).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(delay)


func _open_settings(back_to: String) -> void:
	_settings_back = back_to
	show_panel("settings")


func _refresh_settings() -> void:
	_volume_label.text = I18n.t("SOUND_FMT") % int(round(volume * 100.0))
	_music_label.text = I18n.t("MUSIC_FMT") % int(round(music * 100.0))
	_shake_button.text = I18n.t("SHAKE_FMT") % I18n.t("ON" if shake else "OFF")
	_lang_button.text = I18n.t("LANGUAGE_FMT") % I18n.lang_name()
	_refresh_best()


func _refresh_best() -> void:
	if _best_label:
		_best_label.text = I18n.t("BEST_FMT") % _best if _best > 0 else ""


# ---------------------------------------------------------------- 위젯 도우미

func _panel(key: String, dim: float) -> Control:
	var p := Control.new()
	p.size = Vector2(W, H)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.size = Vector2(W, H)
	bg.color = Color(GameSkin.c("menu_dim"), dim)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bg)
	add_child(p)
	_panels[key] = p
	return p


func _heading(text: String) -> Label:
	var l := _label(text, 70, Vector2(0, 170), W)
	l.add_theme_color_override("font_color", ACCENT)
	return l


func _label(text: String, font_size: int, pos: Vector2, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, font_size * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", GameSkin.c("text"))
	l.add_theme_color_override("font_outline_color", GameSkin.c("outline"))
	l.add_theme_constant_override("outline_size", int(maxi(4, font_size / 7) * GameSkin.c("outline_scale")))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, y: float, on_press: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2((W - BTN_W) / 2.0, y)
	b.size = Vector2(BTN_W, BTN_H)
	b.pivot_offset = b.size / 2.0
	b.add_theme_font_size_override("font_size", 36)
	var base: Color = ACCENT if primary else GameSkin.c("button")
	var text_col: Color = GameSkin.c("on_accent") if primary else GameSkin.c("button_text")
	var edge: Color = Color(0, 0, 0, 0) if primary else GameSkin.c("button_border")
	var hi: Color = Color(GameSkin.c("text"), 0.5)
	b.add_theme_stylebox_override("normal", _box(base, edge))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.15), hi))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.2), hi))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(GameSkin.c("text"), 0.8)))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, text_col)
	b.pressed.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE * 0.94, 0.05)
		t.tween_property(b, "scale", Vector2.ONE, 0.1)
		on_press.call())
	return b


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(22)
	s.border_color = border
	s.set_border_width_all(3 if border.a > 0.0 else 0)
	return s


func _dot(d: int, c: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var a := clampf(r - Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r)), 0.0, 1.0)
			img.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(img)


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and c.visible:
			return c
	return null
