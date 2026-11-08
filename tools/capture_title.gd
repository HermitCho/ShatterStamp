extends SceneTree
## 타이틀 등장 연출 캡처: 연속 프레임(GIF용)과 마지막 정지 화면.
## Godot --path . --script res://tools/capture_title.gd -- [--tagline=I18N키] [--lang=en] <출력 폴더>

func _initialize() -> void:
	var out := ""
	var tagline := ""
	var lang := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tagline="):
			tagline = a.substr(10)
		elif a.begins_with("--lang="):
			lang = a.substr(7)
		else:
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if lang != "":
		I18n.set_lang(lang)
	if tagline != "":
		main.menus._title_items[0].text = tagline
	main.menus.show_title(13675)
	var f := 0
	for i in 170:
		await process_frame
		if i % 2 == 0:
			root.get_texture().get_image().save_png("%s/seq_%04d.png" % [out, f])
			f += 1
	root.get_texture().get_image().save_png(out + "/title.png")
	quit()
