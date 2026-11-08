extends SceneTree
## 결과 화면 연출 캡처: 봇이 몇 번 찍은 뒤 시간을 0으로 만들어 결과 연출을 연속 프레임으로 저장한다.
## Godot --path . --script res://tools/capture_result.gd -- [--lang=en] <출력 폴더>

func _initialize() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			I18n.setup()
			I18n.set_lang(a.substr(7))
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	var main = load("res://scenes/main.tscn").instantiate()
	main.debug_seed = 4242
	main._autoplay = false
	root.add_child(main)
	await process_frame
	main.menus.start_pressed.emit()
	for i in 30: await process_frame
	for step in 12:
		var mv: Dictionary = Bot.best_move(main.board.model, main.current["cells"])
		main.stamp_lock = 0.0
		main.board.locked = false
		main.board.place_at(mv["cell"])
		await create_timer(0.4).timeout
	main.best = 999999  # 최고 기록 갱신 연출이 안 나오게(저장 방지)
	main.rules.time_left = 0.0
	await create_timer(0.9).timeout
	var f := 0
	for i in 300:
		await process_frame
		if i % 2 == 0:
			root.get_texture().get_image().save_png("%s/seq_%04d.png" % [out, f])
			f += 1
	root.get_texture().get_image().save_png(out + "/result.png")
	quit()
