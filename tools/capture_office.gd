extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://scenes/desk.tscn").instantiate()
	scene.progression_enabled = false
	root.add_child(scene)
	var progression = load("res://scripts/progression/desk_progression.gd").new()
	progression.persistence = false
	scene.progression = progression
	scene.add_child(progression)
	progression.setup(scene)
	scene.set_paused(false)
	await create_timer(1.8).timeout
	scene.set_paused(false)
	var filename := "res://docs/captura-automatizacion.png"
	if "--office" in OS.get_cmdline_user_args():
		scene.office.leave_desk()
		scene.office.player.position = Vector3(5.9, -1.04, 3.6)
		scene.office.eye.look_at(Vector3(1.0, 1.0, -5.5))
		filename = "res://docs/captura-oficina.png"
	elif "--shop" in OS.get_cmdline_user_args():
		progression.open_shop()
		await process_frame
		await process_frame
		progression.cards.get_parent().scroll_vertical = 1000
		filename = "res://docs/captura-transporte.png"
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(filename)
	print("CAPTURE: " + filename)
	quit()
