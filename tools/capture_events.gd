extends SceneTree
## 3일차 연출 캡처: 튜토리얼 → 카운트다운 → 연속 PERFECT → 피버 시작/종료 → 마지막 5초 → TIME UP.
## Godot --path . --script res://tools/capture_events.gd -- [--lang=en] <출력 폴더>
## 움직임은 --write-movie <파일.avi>를 같이 주면 영상으로 남고, MARK 줄(프레임 번호)로 구간을 자른다.
## 사용자 저장 파일을 건드리지 않도록 튜토리얼은 끝내지 않고(완료 저장 X), 최고 기록도 갱신하지 않는다.

var main
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--go="):  # GO! 색 시안: --go=r,g,b (0~1)
			var c := a.substr(5).split_floats(",")
			StageFx.go_color = Color(c[0], c[1], c[2])
		elif a.begins_with("--lang="):
			I18n.setup()
			I18n.set_lang(a.substr(7))
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	main.debug_seed = 4242
	main._autoplay = false
	root.add_child(main)
	await process_frame
	main.best = 99999999  # 최고 기록 저장이 일어나지 않게

	# 1) 튜토리얼
	main.tutorial_done = false
	main.menus.start_pressed.emit()
	await _wait(0.6)
	_shot("01_tut1")
	_stamp()
	await _wait(0.1)
	_shot("02_tut_perfect")
	await _wait(0.6)
	_shot("03_tut2")
	_stamp()
	await _wait(0.7)
	_shot("04_tut3")
	_stamp()
	await _wait(0.7)
	_shot("05_tut4_hold")
	main._do_hold()
	await _wait(0.6)
	_shot("06_tut5_ready")
	main._to_title()  # 튜토리얼 완료 저장 전에 빠져나온다
	await _wait(0.3)

	# 2) 카운트다운
	main.tutorial_done = true
	main.menus.start_pressed.emit()
	await _wait(0.08)
	_shot("07_count3")
	await _wait(0.62)
	_shot("08_count2")
	await _wait(1.26)
	_shot("09_go")
	await _wait(0.5)

	# 3) 연속 PERFECT
	for i in 4:
		_stamp()
		await _wait(0.1)
		_shot("1%d_perfect_%d" % [0, i + 1])
		await _wait(0.35)

	# 4) 피버 시작
	main.rules.combo = 9
	main.rules.combo_timer = 2.0
	_stamp()
	await _wait(0.12)
	_shot("20_fever_in")
	await _wait(0.3)
	_shot("21_fever_banner")
	await _wait(1.2)
	_shot("22_fever_play")
	# 5) 피버 종료
	main.rules.combo_timer = 0.01
	await _wait(0.3)
	_shot("23_fever_end")
	await _wait(0.8)

	# 6) 마지막 5초 → TIME UP
	main.rules.time_left = 4.97
	await _wait(0.06)
	_shot("30_last5_beat")
	await _wait(0.6)
	_shot("31_last5_fade")
	main.rules.time_left = 1.05
	await _wait(0.1)
	_shot("32_last1")
	await _wait(1.1)
	_shot("33_timeup")
	await _wait(0.6)
	_shot("34_timeup_hold")
	quit()


func _stamp() -> void:
	var mv: Dictionary = Bot.best_move(main.board.model, main.current["cells"])
	main.stamp_lock = 0.0
	main.board.locked = false
	main.board.place_at(mv["cell"])


func _wait(sec: float) -> Signal:
	return create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	print("MARK %s %d" % [name, Engine.get_frames_drawn()])  # --write-movie로 찍을 때 구간을 자르는 기준
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
