extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://scenes/desk.tscn").instantiate()
	root.add_child(scene)
	for frame in range(15):
		await process_frame
	scene.set_paused(false)
	if "--completed" in OS.get_cmdline_user_args():
		var paper = scene.items[2]
		paper.position = Vector3(0, 0.16, 0)
		paper.add_impression(paper.global_position + Vector3(0.08, 0, 0.32))
		scene.show_message("Solicitud sellada. Déjala en la bandeja de salida.")
	await process_frame
	await RenderingServer.frame_post_draw
	var filename = "res://docs/captura-sellado.png" if "--completed" in OS.get_cmdline_user_args() else "res://docs/captura-mesa.png"
	root.get_texture().get_image().save_png(filename)
	print("CAPTURE: " + filename)
	quit()
