extends SceneTree
const Layout = preload("res://scripts/office/office_layout.gd")
var scene: Node3D
var p: Node
var n: Node
var folder := "res://docs/galeria/"
func _initialize() -> void: call_deferred("capture")
func photo(filename: String) -> void:
	n.update_visuals()
	if n.panel.visible: n.refresh_panel()
	if not scene.office.at_desk: n.update_walk_hud()
	p.refresh()
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png(folder + filename + ".png")
	print("CAPTURE: ", filename, " result=", err)
func walk_to(pos: Vector3, target: Vector3) -> void:
	if scene.office.at_desk: scene.office.leave_desk()
	scene.office.player.position = pos
	scene.office.player.rotation = Vector3.ZERO
	scene.office.eye.look_at(target)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	scene = load("res://scenes/desk.tscn").instantiate()
	scene.progression_enabled = false
	root.add_child(scene)
	p = load("res://scripts/progression/desk_progression.gd").new()
	p.persistence = false
	scene.progression = p
	scene.add_child(p)
	p.setup(scene)
	n = load("res://scripts/office/station_network.gd").new()
	scene.stations = n
	scene.add_child(n)
	n.setup(scene)
	n.set_process(false)
	scene.automation.set_process(false)
	scene.set_process(false)
	scene.office.set_physics_process(false)
	scene.set_paused(false)
	# An isolated demonstration game: buy envelopes without touching the user's save.
	p.economy.balance = 1500
	p.economy.sold = 10
	p.economy.buy(&"envelope_station", 0)
	walk_to(Vector3(0, -1.04, 3.4), Vector3(0, -0.30, -1.2))
	await photo("01-oficina")
	walk_to(Vector3(1.65, -1.04, 1.7), Vector3(0, -0.30, 0))
	await photo("02-mesa-tamano-normal")
	scene.office.sit_down()
	scene.automation.advance(0)
	scene.automation.advance(10)
	await photo("03-carta-lista-para-sellar")
	var stamp: Node3D = scene.items.filter(func(item): return item.kind == "stamp")[0]
	scene.pickup(stamp, scene.camera.unproject_position(stamp.global_position))
	stamp.position = Vector3(0, 0.28, 0)
	assert(scene.try_stamp())
	await create_timer(0.13).timeout
	scene.stroke.pause()
	scene.prompt_label.text = "Clic derecho: el sello baja y deja su marca sobre la carta"
	await photo("04-sellado")
	scene.stroke.play()
	await create_timer(0.3).timeout
	scene.drop_item()
	stamp.position = Vector3(1.53, 0.15, -1.16)
	scene.automation.advance(0)
	scene.automation.advance(10)
	scene.prompt_label.text = "La carta sellada sale sola. Recógela para llevarla a ensobrado o envío"
	await photo("05-carta-sellada-en-salida")
	assert(n.take_stamp_output())
	walk_to(Vector3(2.15, -1.04, -1.15), Vector3(3, -0.25, -2.7))
	await photo("06-mesa-ensobrado")
	n.open_station("envelope")
	assert(n.deposit("envelope") == 1)
	assert(n.start_task("envelope"))
	n.advance(0.65)
	await photo("07-ensobrando-carta")
	n.advance(1.0)
	await photo("08-sobre-listo")
	assert(n.take_envelopes() == 1)
	n.close_station()
	walk_to(Vector3(-2.15, -1.04, -1.15), Vector3(-3, -0.25, -2.7))
	await photo("09-mesa-envio")
	n.open_station("shipping")
	assert(n.deposit("shipping") == 1)
	assert(n.start_task("shipping"))
	n.advance(1.3)
	assert(n.dispatch())
	await photo("10-envio-y-venta")
	n.close_station()
	scene.office.sit_down()
	p.open_shop()
	await photo("11-arbol-mejoras")
	p.tree_view.scroll_horizontal = 1280
	await photo("12-personal-y-rutas")
	p.close_shop()
	for id in ["stamp_employee", "shipping_employee", "envelope_employee", "envelope_courier", "shipping_courier"]:
		p.economy.levels[id] = 1
	walk_to(Vector3(1.8, -1.04, 3.3), Vector3(0, -0.15, -1.0))
	await photo("13-oficina-con-personal")
	quit()
