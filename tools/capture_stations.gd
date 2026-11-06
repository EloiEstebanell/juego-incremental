extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var scene = load("res://scenes/desk.tscn").instantiate()
	scene.progression_enabled = false
	root.add_child(scene)
	var p = load("res://scripts/progression/desk_progression.gd").new()
	p.persistence = false
	scene.progression = p
	scene.add_child(p)
	p.setup(scene)
	var n = load("res://scripts/office/station_network.gd").new()
	scene.stations = n
	scene.add_child(n)
	n.setup(scene)
	p.economy.balance = 2500
	p.economy.sold = 18
	scene.set_paused(false)
	var mode := "desk"
	if not OS.get_cmdline_user_args().is_empty(): mode = OS.get_cmdline_user_args()[0]
	if mode == "tree" or mode == "staff":
		p.open_shop()
		await process_frame
		await process_frame
		if mode == "staff": p.tree_view.scroll_horizontal = 1280
	elif mode == "shipping":
		scene.office.leave_desk()
		n.data().shipping_in_raw = 2
		n.data().shipping_out_enveloped = 1
		p.office_state.cargo = 2
		n.open_station("shipping")
	elif mode == "office":
		for id in ["stamp_employee", "shipping_employee", "envelope_employee", "envelope_station", "direct_courier"]: p.economy.levels[id] = 1
		scene.office.leave_desk()
		scene.office.player.position = Vector3(2.5, -1.04, 2.8)
		scene.office.eye.look_at(Vector3(0, -0.1, -1.5))
	p.refresh()
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/stations-" + mode + ".png")
	quit()
