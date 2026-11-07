class_name Menus
extends CanvasLayer
## 타이틀 / 플레이 방법 / 설정 / 일시정지 / 결과 화면. 버튼을 누르면 신호만 보내고, 실제 흐름은 main.gd가 처리한다.

signal start_pressed
signal resume_pressed
signal restart_pressed
signal title_pressed
signal settings_changed(volume: float, shake: bool)

const W := 720.0
const H := 1280.0
const BTN_W := 420.0
const BTN_H := 92.0
const ACCENT := Color(1.0, 0.85, 0.35)

var volume := 0.8
var shake := true

var _panels: Dictionary = {}
var _settings_back := "title"
var _best_label: Label
var _result_title: Label
var _result_score: Label
var _result_best: Label
var _result_body: Label
var _volume_label: Label
var _volume_slider: HSlider
var _shake_button: Button
var _quit_button: Button


func _ready() -> void:
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
	_best_label.text = "BEST  %d" % best if best > 0 else ""
	show_panel("title")


func show_result(title: String, score: int, best_line: String, body: String) -> void:
	_result_title.text = title
	_result_score.text = str(score)
	_result_best.text = best_line
	_result_body.text = body
	show_panel("result")


func set_settings(v: float, s: bool) -> void:
	volume = v
	shake = s
	_volume_slider.set_value_no_signal(v * 100.0)
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
	var p := _panel("title", 0.86)
	var t := _label("SHATTER", 104, Vector2(0, 190), W)
	t.modulate = ACCENT
	p.add_child(t)
	t = _label("STAMP", 104, Vector2(0, 320), W)
	p.add_child(t)
	var sub := _label("Find the best spot. Shatter it all.", 26, Vector2(0, 470), W)
	sub.modulate = Color(1, 1, 1, 0.6)
	p.add_child(sub)
	_best_label = _label("", 30, Vector2(0, 530), W)
	_best_label.modulate = ACCENT
	p.add_child(_best_label)
	var y := 620.0
	p.add_child(_button("START", y, func(): start_pressed.emit(), true))
	p.add_child(_button("HOW TO PLAY", y + 112, func(): show_panel("howto")))
	p.add_child(_button("SETTINGS", y + 224, func(): _open_settings("title")))
	_quit_button = _button("QUIT", y + 336, func(): get_tree().quit())
	# 웹에서는 창을 닫을 수 없으므로 숨긴다.
	_quit_button.visible = not OS.has_feature("web")
	p.add_child(_quit_button)


func _build_howto() -> void:
	var p := _panel("howto", 0.92)
	p.add_child(_heading("HOW TO PLAY"))
	var body := _label(
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
		+ "Pause: ESC / tap II.", 27, Vector2(0, 280), W)
	body.size.y = 720
	p.add_child(body)
	p.add_child(_button("BACK", 1080, func(): show_panel("title"), true))


func _build_settings() -> void:
	var p := _panel("settings", 0.92)
	p.add_child(_heading("SETTINGS"))
	_volume_label = _label("", 34, Vector2(0, 400), W)
	p.add_child(_volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.step = 5
	_volume_slider.position = Vector2(150, 470)
	_volume_slider.size = Vector2(420, 60)
	_volume_slider.add_theme_icon_override("grabber", _dot(30, Color.WHITE))
	_volume_slider.add_theme_icon_override("grabber_highlight", _dot(34, ACCENT))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	_volume_slider.add_theme_stylebox_override("slider", track)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = ACCENT
	_volume_slider.add_theme_stylebox_override("grabber_area", filled)
	_volume_slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	_volume_slider.value_changed.connect(func(v: float):
		volume = v / 100.0
		_refresh_settings()
		settings_changed.emit(volume, shake))
	p.add_child(_volume_slider)

	_shake_button = _button("", 600, func():
		shake = not shake
		_refresh_settings()
		settings_changed.emit(volume, shake))
	p.add_child(_shake_button)
	p.add_child(_button("BACK", 1080, func(): show_panel(_settings_back), true))
	_refresh_settings()


func _build_pause() -> void:
	var p := _panel("pause", 0.97)
	p.add_child(_heading("PAUSED"))
	var y := 440.0
	p.add_child(_button("RESUME", y, func(): resume_pressed.emit(), true))
	p.add_child(_button("RESTART", y + 112, func(): restart_pressed.emit()))
	p.add_child(_button("SETTINGS", y + 224, func(): _open_settings("pause")))
	p.add_child(_button("TITLE", y + 336, func(): title_pressed.emit()))


func _build_result() -> void:
	var p := _panel("result", 0.8)
	_result_title = _heading("")
	p.add_child(_result_title)
	var l := _label("SCORE", 28, Vector2(0, 300), W)
	l.modulate = Color(1, 1, 1, 0.55)
	p.add_child(l)
	_result_score = _label("", 92, Vector2(0, 336), W)
	p.add_child(_result_score)
	_result_best = _label("", 32, Vector2(0, 470), W)
	_result_best.modulate = ACCENT
	p.add_child(_result_best)
	_result_body = _label("", 28, Vector2(0, 550), W)
	_result_body.size.y = 300
	p.add_child(_result_body)
	p.add_child(_button("RETRY", 900, func(): restart_pressed.emit(), true))
	p.add_child(_button("TITLE", 1012, func(): title_pressed.emit()))


func _open_settings(back_to: String) -> void:
	_settings_back = back_to
	show_panel("settings")


func _refresh_settings() -> void:
	_volume_label.text = "SOUND  %d%%" % int(round(volume * 100.0))
	_shake_button.text = "SCREEN SHAKE: %s" % ("ON" if shake else "OFF")


# ---------------------------------------------------------------- 위젯 도우미

func _panel(key: String, dim: float) -> Control:
	var p := Control.new()
	p.size = Vector2(W, H)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.size = Vector2(W, H)
	bg.color = Color(0.03, 0.03, 0.06, dim)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bg)
	add_child(p)
	_panels[key] = p
	return p


func _heading(text: String) -> Label:
	var l := _label(text, 70, Vector2(0, 170), W)
	l.modulate = ACCENT
	return l


func _label(text: String, font_size: int, pos: Vector2, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, font_size * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, y: float, on_press: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2((W - BTN_W) / 2.0, y)
	b.size = Vector2(BTN_W, BTN_H)
	b.pivot_offset = b.size / 2.0
	b.add_theme_font_size_override("font_size", 36)
	var base := ACCENT if primary else Color(0.2, 0.2, 0.28)
	var text_col := Color(0.08, 0.06, 0.1) if primary else Color.WHITE
	b.add_theme_stylebox_override("normal", _box(base, Color(0, 0, 0, 0)))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.15), Color(1, 1, 1, 0.5)))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.2), Color(1, 1, 1, 0.5)))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.8)))
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
