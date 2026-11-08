class_name Music
extends Node
## 배경 음악. 타이틀 곡 / 게임 곡 + 피버 층(게임 곡과 길이가 같아 같이 틀어 두고 소리만 올린다).
## 음악 파일은 tools/make_bgm.gd 로 코드에서 합성해 만든 것.

const BUS := "Music"
const OFF_DB := -60.0

var _title: AudioStreamPlayer
var _game: AudioStreamPlayer
var _fever: AudioStreamPlayer
var _tweens: Dictionary = {}


func _ready() -> void:
	_title = _player("res://assets/audio/bgm_title.wav")
	_game = _player("res://assets/audio/bgm_game.wav")
	_fever = _player("res://assets/audio/bgm_fever.wav")


func _player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = BUS
	p.volume_db = OFF_DB
	add_child(p)
	return p


func play_title() -> void:
	_fade(_game, OFF_DB, 0.4, true)
	_fade(_fever, OFF_DB, 0.4, true)
	if not _title.playing:
		_title.play()
	_fade(_title, -4.0, 0.8)


func play_game() -> void:
	_fade(_title, OFF_DB, 0.3, true)
	_game.stop()
	_fever.stop()
	_game.volume_db = -3.0
	_fever.volume_db = OFF_DB
	_game.play()
	_fever.play()  # 같은 순간에 시작해 박자가 맞는다


func set_fever(on: bool) -> void:
	_fade(_fever, -3.0 if on else OFF_DB, 0.5 if on else 1.0)


## 일시정지 중에는 소리를 낮춘다.
func set_paused(on: bool) -> void:
	_game.stream_paused = false
	_fade(_game, -16.0 if on else -3.0, 0.25)
	if on:
		_fade(_fever, OFF_DB, 0.25)


## 게임 끝: 게임 곡을 서서히 줄여 멈춘다.
func end_game() -> void:
	_fade(_game, OFF_DB, 1.2, true)
	_fade(_fever, OFF_DB, 0.6, true)


func _fade(p: AudioStreamPlayer, db: float, dur: float, stop_after := false) -> void:
	if _tweens.has(p) and _tweens[p].is_valid():
		_tweens[p].kill()
	var t := create_tween()
	t.tween_property(p, "volume_db", db, dur)
	if stop_after:
		t.tween_callback(p.stop)
	_tweens[p] = t
