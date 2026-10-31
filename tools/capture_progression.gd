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
	for frame in range(15):
		await process_frame
	scene.set_paused(false)
	var filename := "res://docs/captura-economia.png"
	if "--shop" in OS.get_cmdline_user_args():
		progression.economy.balance = 450
		progression.refresh()
		progression.open_shop()
		filename = "res://docs/captura-mejoras.png"
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(filename)
	print("CAPTURE: " + filename)
	quit()
