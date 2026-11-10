class_name StageFx
extends CanvasLayer
## 판 전체에 걸친 큰 연출: 시작 카운트다운, TIME UP, 피버 시작/종료 배너, 화면 가장자리 빛(비네트).
## HUD 위, 메뉴 아래 층에 그린다. 글자는 두 언어 모두 영어(연출 문구 규칙).

signal count_beat(n: int)  ## 3, 2, 1, 0(GO)

const W := 720.0
const H := 1280.0
const CENTER_Y := 720.0

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.1, 0.2, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	d.y *= 0.9;
	float e = smoothstep(0.55, 1.15, length(d * vec2(1.0, 0.85)) );
	float edge = max(smoothstep(0.86, 1.0, d.x), smoothstep(0.9, 1.0, d.y));
	COLOR = vec4(tint.rgb, tint.a * amount * clamp(e * 0.85 + edge * 0.6, 0.0, 1.0));
}
"""

var danger_vignette: ColorRect
var fever_vignette: ColorRect
var _run := 0
## GO! 글자 색(시안 비교 캡처에서 바꿔 볼 수 있게 static)
static var go_color := Color(1.0, 0.82, 0.2)  # 노랑(시간 숫자 톤) — 사용자 선택 B
## 피버 동안 보드 위쪽 빈 공간에 떠 있는 배지(끝날 때 떨어진다)
var _fever_badge: Label
var _t := 0.0


func _ready() -> void:
	layer = 3
	danger_vignette = _vignette(Color(1.0, 0.08, 0.15))
	fever_vignette = _vignette(GameSkin.c("tiers")[3])


## 0~1. 마지막 5초 경고처럼 계속 바뀌는 값을 매 프레임 넣는다.
func set_danger(v: float) -> void:
	danger_vignette.material.set_shader_parameter("amount", v)


## 피버 중 분홍 가장자리 빛(심장 박동처럼 뛴다).
func set_fever_glow(v: float) -> void:
	fever_vignette.material.set_shader_parameter("amount", v)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_fever_badge) and not _fever_badge.has_meta("ending"):
		# 둥둥 뛰는 크기 + 테두리 색이 분홍↔보라↔하늘로 돈다
		_fever_badge.scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * 9.0))
		var h := fmod(0.92 + 0.12 * sin(_t * 2.5), 1.0)
		_fever_badge.add_theme_color_override("font_outline_color", Color.from_hsv(h, 0.75, 1.0, 0.9))


func clear() -> void:
	_run += 1
	_fever_badge = null
	set_danger(0.0)
	set_fever_glow(0.0)
	for c in get_children():
		if c != danger_vignette and c != fever_vignette:
			c.queue_free()


# ---------------------------------------------------------------- 카운트다운

## 3, 2, 1, GO! — 끝나면 true. 중간에 clear()되면 false.
func countdown() -> bool:
	_run += 1
	var run := _run
	for n in [3, 2, 1]:
		count_beat.emit(n)
		var l := _big(str(n), 220, Color(GameSkin.c("text")))
		_slam(l, 2.2, 0.16)
		var t := l.create_tween()
		t.tween_interval(0.5)
		t.tween_property(l, "modulate:a", 0.0, 0.2)
		t.parallel().tween_property(l, "scale", Vector2.ONE * 0.7, 0.2)
		t.tween_callback(l.queue_free)
		await get_tree().create_timer(0.62).timeout
		if run != _run:
			return false
	count_beat.emit(0)
	_go()
	return true


## GO!: 테두리·판 없이 글자만. 글자 둘레에 네온처럼 번지는 빛을 칠한다.
## 3·2·1(흰 글자 + 하늘색 빛)과 같은 톤에서 색만 분홍으로 달리 했다. 쾅 찍히고 지직 깜빡이며 켜졌다가 꺼지듯 사라진다.
func _go() -> void:
	var sign := NeonText.new()
	sign.text = "GO!"
	sign.font_size = 200
	sign.spacing = 4.0
	sign.color = go_color
	sign.core_white = 0.72  # 속은 흰빛, 테두리는 노랑
	sign.position = Vector2(W / 2.0, CENTER_Y)
	sign.scale = Vector2.ONE * 1.8
	sign.glow = 0.0
	add_child(sign)
	var t := sign.create_tween()
	t.set_parallel()
	t.tween_property(sign, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(sign, "glow", 1.0, 0.05)
	t.chain().tween_property(sign, "scale", Vector2.ONE * 1.04, 0.06)
	t.chain().tween_property(sign, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 지직: 켜진 직후 한 번 깜빡
	t.tween_property(sign, "glow", 0.35, 0.03).set_delay(0.06)
	t.chain().tween_property(sign, "glow", 1.0, 0.03)
	t.chain().tween_interval(0.3)
	# 꺼짐: 두 번 깜빡이고 사라진다
	t.chain().tween_property(sign, "glow", 0.2, 0.04)
	t.chain().tween_property(sign, "glow", 0.9, 0.04)
	t.chain().tween_property(sign, "glow", 0.0, 0.18)
	t.chain().tween_callback(sign.queue_free)


# ---------------------------------------------------------------- 시간 종료

func time_up() -> void:
	var band := _band(CENTER_Y, 170.0, Color(0.02, 0.01, 0.05, 0.82))
	band.scale.y = 0.0
	band.create_tween().tween_property(band, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var l := _big("TIME UP!", 120, Color(1.0, 0.35, 0.35))
	_slam(l, 2.6, 0.14)


# ---------------------------------------------------------------- 피버

const BADGE_Y := 238.0


func fever_start() -> void:
	if is_instance_valid(_fever_badge):
		_fever_badge.queue_free()
	var l := _big("FEVER!  x3", 66, Color.WHITE)
	l.position.y = BADGE_Y - l.size.y / 2.0
	l.add_theme_color_override("font_outline_color", GameSkin.c("tiers")[3])
	l.add_theme_constant_override("outline_size", 14)
	_fever_badge = l
	_slam(l, 2.4, 0.14)
	# 배지 자리에서 퍼지는 빛 글자(한 번)
	var glow := _big("FEVER!  x3", 66, Color(GameSkin.c("tiers")[3], 0.6))
	glow.position.y = l.position.y
	glow.add_theme_constant_override("outline_size", 30)
	glow.add_theme_color_override("font_outline_color", Color(GameSkin.c("tiers")[3], 0.3))
	var tg := glow.create_tween().set_parallel()
	tg.tween_interval(0.12)
	tg.tween_property(glow, "scale", Vector2.ONE * 1.8, 0.45).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tg.tween_property(glow, "modulate:a", 0.0, 0.45).set_delay(0.12)
	tg.chain().tween_callback(glow.queue_free)


## 판이 끝나거나 타이틀로 갈 때: 연출 없이 배지만 치운다.
func hide_fever_badge() -> void:
	if is_instance_valid(_fever_badge):
		_fever_badge.queue_free()
	_fever_badge = null


## 배지가 회색 FEVER END로 바뀌어 기울며 떨어진다.
func fever_end() -> void:
	if not is_instance_valid(_fever_badge):
		return
	var l := _fever_badge
	_fever_badge = null
	l.set_meta("ending", true)
	l.text = "FEVER END"
	l.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.18, 0.28))
	l.scale = Vector2.ONE
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y + 90.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.35)
	t.tween_property(l, "rotation", 0.08, 0.8)
	t.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- 도우미

func _vignette(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.size = Vector2(W, H)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("amount", 0.0)
	r.material = m
	add_child(r)
	return r


func _big(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.size = Vector2(W, font_size * 1.4)
	l.position = Vector2(0, CENTER_Y - l.size.y / 2.0)
	l.pivot_offset = l.size / 2.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", GameSkin.c("outline"))
	l.add_theme_constant_override("outline_size", int(maxi(6, font_size / 9) * GameSkin.c("outline_scale")))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## 가로로 화면을 가로지르는 띠. pivot은 띠 가운데.
func _band(cy: float, h: float, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.size = Vector2(W * 1.2, h)
	r.position = Vector2(-W * 0.1, cy - h / 2.0)
	r.pivot_offset = r.size / 2.0
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## 크게(또는 작게) 시작해 제자리 크기로 쾅 내려앉는다.
func _slam(c: Control, from_scale: float, dur: float, grow := false) -> void:
	c.scale = Vector2.ONE * from_scale
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel()
	if grow:
		t.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		t.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(c, "modulate:a", 1.0, dur * 0.5)
