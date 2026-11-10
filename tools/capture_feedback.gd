extends SceneTree
## 피드백 반영 캡처: 판정 색 미리보기(PERFECT/GREAT/GOOD/MISS) → 번지는 파괴 → MISS 판정 글자 → 게임 방법 카드.
## Godot --path . --script res://tools/capture_feedback.gd -- [--lang=en] <출력 폴더>
## 최고 기록을 건드리지 않는다.

var main
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
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
	main.best = 99999999
	main.tutorial_done = true
	main.menus.start_pressed.emit()
	await _wait(2.6)  # 카운트다운

	# 1) 미리보기: 등급마다 대표 자리에 마우스를 올린 상태
	var moves := Bot.all_moves(main.board.model, main.current["cells"])
	var best_n: int = moves[0]["count"]
	for g in 4:
		var mv = null
		for m in moves:
			if GameRules.grade_for(m["count"], best_n) == g:
				mv = m
				break
		if mv == null:
			continue
		main.board._set_anchor(mv["cell"], true)
		await _wait(0.1)
		_shot("1%d_preview_%s" % [g, GameRules.GRADE_NAMES[g]])

	# 2) 번지는 파괴: 찍고 아주 짧게 기다렸다가 찍기
	var big := Bot.best_move(main.board.model, main.current["cells"])
	main.board._set_anchor(big["cell"], true)
	main.board.place_at(big["cell"])
	await _wait(0.07)
	_shot("20_wave_mid")
	await _wait(0.5)
	_shot("21_perfect_text")
	await _wait(0.6)

	# 3) MISS: 가장 적게 부수는 자리
	main.stamp_lock = 0.0
	main.board.locked = false
	var worst: Dictionary = Bot.all_moves(main.board.model, main.current["cells"]).back()
	main.board.place_at(worst["cell"])
	await _wait(0.15)
	_shot("30_miss_text")
	await _wait(0.8)

	# 4) 게임 방법
	main._to_title()
	await _wait(0.3)
	main.menus.show_panel("howto")
	await _wait(0.4)
	_shot("40_howto")
	quit()


func _wait(sec: float) -> Signal:
	return create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
