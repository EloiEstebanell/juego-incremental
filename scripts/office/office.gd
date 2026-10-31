extends Node3D
const Geo = preload("res://scripts/geometry.gd")
const Economy = preload("res://scripts/progression/economy.gd")
var desk: Node3D
var at_desk := true
var player: CharacterBody3D
var eye: Camera3D
var world: Node3D
var walk_ui: Control
var walk_pause: PanelContainer
var hint: Label
var ledger: Label
var carried_visual: Node3D
var job_remaining := 0.0
var job_duration := 1.5
var message := ""
var message_time := 0.0
var look_sensitivity := 0.0025
const ANCHORS := {"desk": Vector3(0, 0, 3.6), "pickup": Vector3(3.55, 0, 3.6), "envelopes": Vector3(6.4, 0, -4.0), "shipping": Vector3(-6.4, 0, -4.0)}

func setup(owner_desk: Node3D) -> void:
	desk = owner_desk
	world = Node3D.new()
	add_child(world)
	build_office()
	player = CharacterBody3D.new()
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.7
	capsule.radius = 0.28
	shape.shape = capsule
	shape.position.y = 0.85
	player.add_child(shape)
	player.position = Vector3(0, -1.04, 4.1)
	eye = Camera3D.new()
	player.add_child(eye)
	eye.position.y = 1.58
	eye.fov = 78
	eye.near = 0.05
	carried_visual = Node3D.new()
	eye.add_child(carried_visual)
	carried_visual.hide()
	for index in range(3):
		Geo.box(carried_visual, Vector3(0.38, 0.008, 0.48), Vector3(0.29, -0.34 + index * 0.012, -0.65), Color("e8dfbd"))
	for action in {"office_forward": KEY_W, "office_back": KEY_S, "office_left": KEY_A, "office_right": KEY_D}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = {"office_forward": KEY_W, "office_back": KEY_S, "office_left": KEY_A, "office_right": KEY_D}[action]
			InputMap.action_add_event(action, event)
	build_ui()
	world.hide()
	walk_ui.hide()

func solid(size: Vector3, pos: Vector3, color: Color, draw := true) -> void:
	if draw:
		Geo.box(world, size, pos, color)
	var body := StaticBody3D.new()
	world.add_child(body)
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func sign_text(text: String, pos: Vector3, color: Color, size: int = 42) -> void:
	var label := Geo.label(world, text, pos, size, color, 0.009)
	label.rotation_degrees.x = 0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if pos.z > 2:
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED

func build_office() -> void:
	solid(Vector3(18, 0.18, 16), Vector3(0, -1.16, 0), Color("364c48"))
	for x in range(-8, 9, 2):
		for z in range(-7, 8, 2):
			Geo.box(world, Vector3(1.98, 0.006, 1.98), Vector3(x, -1.065, z), Color("45605a") if (x + z) % 4 else Color("3b554e"))
	solid(Vector3(18, 0.15, 16), Vector3(0, 3.1, 0), Color("96a28a"))
	for x in [-9.0, 9.0]:
		solid(Vector3(0.2, 4, 16), Vector3(x, 0.9, 0), Color("8c9d8a"))
	for z in [-8.0, 8.0]:
		solid(Vector3(18, 4, 0.2), Vector3(0, 0.9, z), Color("a4ac96"))
	# The workstation, walls and counters are physical obstacles for walking.
	solid(Vector3(10.2, 1.1, 5.6), Vector3(0, -0.55, 0), Color.BLACK, false)
	for x in [-4.4, 4.4]:
		for z in [-2.1, 2.1]:
			Geo.box(world, Vector3(0.18, 0.8, 0.18), Vector3(x, -0.65, z), Color("273b37"))
	for x in [-6.4, 6.4]:
		solid(Vector3(3.0, 1.1, 1.7), Vector3(x, -0.5, -5.5), Color("29443e"))
		Geo.box(world, Vector3(3.12, 0.08, 1.8), Vector3(x, 0.09, -5.5), Color("b48d60"))
		Geo.box(world, Vector3(2.4, 0.12, 0.14), Vector3(x, 0.35, -6.1), Color("c1aa78"))
	sign_text("02 / SOBRES", Vector3(6.4, 1.45, -6.1), Color("f3e4b8"))
	sign_text("Procesa tu carga · valor ×2", Vector3(6.4, 0.95, -6.1), Color("e8e0c5"), 24)
	sign_text("03 / EXPEDICIÓN", Vector3(-6.4, 1.45, -6.1), Color("f3e4b8"))
	sign_text("Entrega y cobra tu carga", Vector3(-6.4, 0.95, -6.1), Color("e8e0c5"), 24)
	sign_text("01 / SELLADO", Vector3(0, -0.1, 2.86), Color("eee0b5"))
	sign_text("RECOGIDA", Vector3(3.55, -0.1, 2.86), Color("e8d4a0"), 28)
	for index in range(5):
		Geo.box(world, Vector3(0.6, 0.014, 0.42), Vector3(6.0, 0.15 + index * 0.017, -5.3), Color("e1d1a7"))
	Geo.box(world, Vector3(0.9, 0.6, 0.7), Vector3(-6.4, 0.43, -5.5), Color("b68b53"))
	for x in [-8.2, 8.2]:
		Geo.cylinder(world, 0.33, 0.52, Vector3(x, -0.8, 6.7), Color("a5754e"))
		Geo.cylinder(world, 0.44, 0.8, Vector3(x, -0.12, 6.7), Color("40634d"))
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.7, -5)
	fill.omni_range = 15
	fill.light_energy = 0.8
	world.add_child(fill)
	for light_position in [Vector3(0, 2.5, 3.5), Vector3(6, 2.5, -3.5), Vector3(-6, 2.5, -3.5)]:
		var interior := OmniLight3D.new()
		interior.position = light_position
		interior.omni_range = 12
		interior.light_energy = 1.4
		world.add_child(interior)
		var fixture := Geo.box(world, Vector3(1.8, 0.04, 0.5), Vector3(light_position.x, 2.99, light_position.z), Color("f1e9ce"))
		fixture.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func build_ui() -> void:
	var leave: Button = desk.make_button("Levantarse · E", leave_desk)
	desk.ui.add_child(leave)
	leave.position = Vector2(42, 198)
	var layer := CanvasLayer.new()
	add_child(layer)
	walk_ui = Control.new()
	layer.add_child(walk_ui)
	walk_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	walk_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = desk.text_label("OFICINA CENTRAL  /  EN MOVIMIENTO", 20, Color("f5e8c7"))
	walk_ui.add_child(title)
	title.position = Vector2(35, 26)
	ledger = desk.text_label("", 20, Color("f5e8c7"))
	walk_ui.add_child(ledger)
	ledger.position = Vector2(35, 62)
	var controls: Label = desk.text_label("W A S D  caminar  ·  RATÓN  mirar  ·  E  interactuar  ·  ESC  pausa", 18, Color("efdfb9"))
	walk_ui.add_child(controls)
	controls.position = Vector2(35, 105)
	var cross: Label = desk.text_label("+", 28, Color("f5e8c7"))
	walk_ui.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.offset_left = -8
	cross.offset_top = -16
	var panel := PanelContainer.new()
	walk_ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = -90
	panel.offset_bottom = -25
	panel.add_theme_stylebox_override("panel", desk.panel_style(Color("172d2d"), Color("657260")))
	hint = desk.text_label("", 21, Color("f5e8c7"))
	panel.add_child(hint)
	walk_pause = PanelContainer.new()
	walk_ui.add_child(walk_pause)
	walk_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	walk_pause.offset_left = -220
	walk_pause.offset_right = 220
	walk_pause.offset_top = -110
	walk_pause.offset_bottom = 110
	walk_pause.add_theme_stylebox_override("panel", desk.panel_style(Color("172d2d"), Color("a6ad87")))
	var buttons := VBoxContainer.new()
	walk_pause.add_child(buttons)
	buttons.add_child(desk.text_label("La oficina puede esperar.", 26, Color("f3ecd9")))
	buttons.add_child(desk.make_button("Continuar", desk.toggle_pause))
	buttons.add_child(desk.make_button("Salir", func(): get_tree().quit()))
	walk_pause.hide()

func sync_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if at_desk or desk.paused else Input.MOUSE_MODE_CAPTURED
	if walk_pause:
		walk_pause.visible = desk.paused

func leave_desk() -> void:
	if not at_desk or desk.busy or desk.paused:
		return
	if desk.held:
		desk.drop_item()
	at_desk = false
	player.position = Vector3(0, -1.04, 4.1)
	player.rotation = Vector3.ZERO
	eye.rotation = Vector3.ZERO
	eye.current = true
	world.show()
	desk.ui.hide()
	walk_ui.show()
	sync_mouse()

func sit_down() -> void:
	if job_remaining > 0:
		return
	at_desk = true
	desk.camera.current = true
	world.hide()
	walk_ui.hide()
	carried_visual.hide()
	desk.ui.show()
	sync_mouse()

func handle_input(event: InputEvent) -> bool:
	if desk.progression and desk.progression.overlay.visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and not desk.paused:
			if at_desk:
				leave_desk()
			else:
				interact()
			return true
		if not at_desk and event.physical_keycode == KEY_ESCAPE:
			desk.toggle_pause()
			return true
	if not at_desk:
		if event is InputEventMouseMotion and not desk.paused:
			player.rotate_y(-event.relative.x * look_sensitivity)
			eye.rotation.x = clampf(eye.rotation.x - event.relative.y * look_sensitivity, -1.25, 1.25)
		return true
	return false

func nearest_station() -> String:
	var closest := ""
	var distance := 2.0
	for key in ANCHORS:
		var delta: Vector3 = player.position - ANCHORS[key]
		delta.y = 0
		if delta.length() < distance:
			distance = delta.length()
			closest = key
	return closest

func _physics_process(delta: float) -> void:
	if desk == null or at_desk or desk.paused:
		return
	var direction := Input.get_vector("office_left", "office_right", "office_forward", "office_back")
	var motion := player.basis * Vector3(direction.x, 0, direction.y) if job_remaining <= 0 else Vector3.ZERO
	player.velocity.x = motion.x * 3.6
	player.velocity.z = motion.z * 3.6
	player.velocity.y -= 15 * delta
	player.move_and_slide()
	if player.position.y < -4:
		player.position = Vector3(0, -1.04, 4.1)
		player.velocity = Vector3.ZERO
	if job_remaining > 0:
		job_remaining = maxf(0, job_remaining - delta)
		if job_remaining == 0:
			finish_envelopes()
	message_time = maxf(0, message_time - delta)
	update_hud()

func state() -> Dictionary:
	return desk.progression.office_state if desk.progression else {"cargo": 0, "enveloped": false}

func tell(value: String) -> void:
	message = value
	message_time = 3.0

func update_hud() -> void:
	var cargo: int = int(state().cargo)
	carried_visual.visible = cargo > 0
	for index in range(carried_visual.get_child_count()):
		carried_visual.get_child(index).visible = index < cargo
	ledger.text = "Carga: %d / 3  ·  %s  ·  Saldo: %s" % [cargo, "sobres listos" if state().enveloped else "documentos sellados", Economy.money(desk.progression.economy.balance) if desk.progression else "—"]
	if job_remaining > 0:
		hint.text = "Ensobrando tu carga… %d %%" % int(100 * (1 - job_remaining / job_duration))
	elif message_time > 0:
		hint.text = message
	else:
		match nearest_station():
			"desk": hint.text = "E · Sentarse a sellar"
			"pickup": hint.text = "E · Recoger documentos de la salida (capacidad: 3)"
			"envelopes": hint.text = "E · Ensobrar la carga — paga el doble en expedición"
			"shipping": hint.text = "E · Vender la carga en expedición"
			_: hint.text = "Sobres: fondo derecha  ·  Expedición: fondo izquierda  ·  Rodea la mesa"

func interact() -> void:
	if desk.paused or at_desk or job_remaining > 0:
		return
	match nearest_station():
		"desk": sit_down()
		"pickup": take_output()
		"envelopes": start_envelopes()
		"shipping": sell_cargo()

func take_output() -> bool:
	if not desk.progression or not desk.progression.store.writable or int(state().cargo) > 0:
		tell("Entrega la carga que llevas antes de recoger otra.")
		return false
	var candidates: Array = []
	for item in desk.items:
		if item.kind == "paper" and not item.impressions.is_empty() and item.position.x - item.half_size.x >= desk.OUTPUT_X and absf(item.position.z) + item.half_size.y <= 1.83 and not (desk.automation and desk.automation.moving == item):
			candidates.append(item)
	if candidates.is_empty():
		tell("Todavía no hay documentos sellados en la salida.")
		return false
	for paper in candidates:
		desk.items.erase(paper)
	desk.progression.office_state = {"cargo": candidates.size(), "enveloped": false}
	if not desk.progression.persist():
		desk.items.append_array(candidates)
		desk.progression.office_state = {"cargo": 0, "enveloped": false}
		tell("No se pudo guardar. La recogida se ha cancelado.")
		return false
	for paper in candidates:
		if desk.hovered == paper:
			desk.hovered = null
		desk.item_root.remove_child(paper)
		paper.queue_free()
	desk.update_delivery()
	if desk.items.size() == 1:
		desk.reset_desk()
	tell("Carga recogida. Llévala a sobres o véndela en expedición.")
	return true

func start_envelopes() -> bool:
	if not desk.progression or int(state().cargo) == 0 or state().enveloped or job_remaining > 0:
		tell("Necesitas una carga de documentos sellados sin ensobrar.")
		return false
	job_remaining = job_duration
	return true

func finish_envelopes() -> void:
	desk.progression.office_state.enveloped = true
	if not desk.progression.persist():
		desk.progression.office_state.enveloped = false
		tell("No se pudo guardar. Conservas los documentos originales.")
	else:
		tell("Sobres listos. Llévalos a expedición: valor ×2.")

func sell_cargo() -> bool:
	if not desk.progression or int(state().cargo) == 0 or job_remaining > 0 or not desk.progression.store.writable:
		tell("No hay una carga lista para entregar.")
		return false
	var old_state: Dictionary = state().duplicate()
	var old_economy: Dictionary = desk.progression.economy.snapshot()
	var payment: int = desk.progression.economy.payout() * int(state().cargo) * (2 if state().enveloped else 1)
	if desk.progression.economy.balance + payment > Economy.LIMIT:
		return false
	desk.progression.economy.balance += payment
	desk.progression.economy.sold += int(state().cargo)
	desk.progression.office_state = {"cargo": 0, "enveloped": false}
	if not desk.progression.persist():
		desk.progression.office_state = old_state
		desk.progression.economy.restore(old_economy)
		tell("Venta cancelada: no se pudo guardar. Conservas la carga.")
		return false
	desk.progression.refresh()
	tell("Entrega cobrada: +" + Economy.money(payment))
	return true

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
