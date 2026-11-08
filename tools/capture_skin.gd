extends SceneTree
## 디자인 시안 캡처: 같은 시드로 타이틀 / 미리보기 / 파괴 순간 스틸과 GIF용 연속 프레임을 저장한다.
## Godot --path . --script res://tools/capture_skin.gd -- [--skin=classic] <출력 폴더>

var out := ""

func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out + "/" + name + ".png")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	var main = load("res://scenes/main.tscn").instantiate()
	main.debug_seed = 4242
	root.add_child(main)
	await _frames(3)
	main._new_board()
	await _frames(60)
	_save("title")
	main.menus.start_pressed.emit()
	await _frames(70)
	var mv: Dictionary = Bot.best_move(main.board.model, main.current["cells"])
	main.board._set_anchor(mv["cell"], true)
	await _frames(6)
	_save("preview")
	# 연속 프레임: 봇이 0.45초 간격으로 4번 찍는 장면
	var f := 0
	for step in 4:
		mv = Bot.best_move(main.board.model, main.current["cells"])
		main.board._set_anchor(mv["cell"], true)
		for i in 8:
			await process_frame
			if i % 2 == 0:
				_save("seq_%04d" % f)
				f += 1
		main.board.place_at(mv["cell"])
		for i in 20:
			await process_frame
			if i % 2 == 0:
				_save("seq_%04d" % f)
				f += 1
			if step == 0 and i == 3:
				_save("break")
	main._enter_fever()
	await _frames(30)
	_save("fever")
	quit()
