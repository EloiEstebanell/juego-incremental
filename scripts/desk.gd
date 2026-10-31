extends Node3D
const Geo = preload("res://scripts/geometry.gd")
const DeskItem = preload("res://scripts/desk_item.gd")
const TABLE_HALF := Vector2(4.8, 2.5)
const OUTPUT_X := 2.65
@export var progression_enabled := true
@export var automation_enabled := true
@export var office_enabled := true
var automation: Node
var office: Node
var progression: Node
var camera: Camera3D
var items: Array = []
var held: Node3D
var hovered: Node3D
var grab_offset := Vector3.ZERO
var cursor := Vector2.ZERO
var busy := false
var paused := false
var stroke: Tween
var stroke_target: Node3D
var stamp_rest_y := 0.0
var status_label: Label
var count_label: Label
var prompt_label: Label
var pause_panel: PanelContainer
var item_root: Node3D
var delivery_count := 0
var message_time := 0.0
var ui: Control

func _ready() -> void:
	build_room()
	build_ui()
	reset_desk()
	cursor = get_viewport().get_visible_rect().size * 0.5
	if progression_enabled:
		progression = preload("res://scripts/progression/desk_progression.gd").new()
		add_child(progression)
		progression.setup(self)
	if automation_enabled:
		automation = preload("res://scripts/office/paper_flow.gd").new()
		add_child(automation)
		automation.setup(self)
	if office_enabled:
		office = preload("res://scripts/office/office.gd").new()
		add_child(office)
		office.setup(self)

func build_room() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("17282c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.3
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -32, 0)
	light.light_color = Color.WHITE
	light.light_energy = 0.65
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 9.8, 7.5)
	camera.look_at(Vector3(0, 0, 0.0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.3
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.current = true
	Geo.box(self, Vector3(200, 0.2, 200), Vector3(0, -1.2, 0), Color("1d3337"))
	Geo.box(self, Vector3(10.2, 0.32, 5.6), Vector3(0, -0.20, 0), Color("835b3e"))
	Geo.box(self, Vector3(10.0, 0.07, 5.4), Vector3(0, -0.015, 0), Color("b3895d"))
	# Deliberately quiet wood joins and a dark desk pad keep papers readable.
	for x in [-3.3, -1.65, 0.0, 1.65, 3.3]:
		Geo.box(self, Vector3(0.012, 0.003, 5.35), Vector3(x, 0.023, 0), Color("a17b53"))
	Geo.box(self, Vector3(4.5, 0.035, 4.45), Vector3(0, 0.027, 0), Color("2d514d"))
	for x in [-2.17, 2.17]:
		Geo.box(self, Vector3(0.012, 0.002, 4.30), Vector3(x, 0.047, 0), Color("678079"))
	for z in [-2.14, 2.14]:
		Geo.box(self, Vector3(4.35, 0.002, 0.012), Vector3(0, 0.047, z), Color("678079"))
	for x in [-3.55, 3.55]:
		Geo.box(self, Vector3(2.16, 0.025, 3.55), Vector3(x, 0.04, 0.10), Color("886546"))
		for side in [-1, 1]:
			Geo.box(self, Vector3(0.025, 0.07, 3.55), Vector3(x + side * 1.08, 0.07, 0.10), Color("c6a06b"))
		Geo.box(self, Vector3(2.16, 0.07, 0.025), Vector3(x, 0.07, -1.67), Color("c6a06b"))
	Geo.label(self, "01  /  ENTRADA", Vector3(-3.55, 0.06, -2.03), 29, Color("332f29"), 0.0034)
	Geo.label(self, "02  /  TRAMITACIÓN", Vector3(0, 0.06, -1.93), 28, Color("c0c7ad"), 0.0034)
	Geo.label(self, "03  /  SALIDA", Vector3(3.55, 0.06, -2.03), 29, Color("332f29"), 0.0034)
	Geo.box(self, Vector3(0.98, 0.09, 0.8), Vector3(1.53, 0.09, -1.16), Color("1d3634"))
	Geo.box(self, Vector3(0.84, 0.012, 0.66), Vector3(1.53, 0.142, -1.16), Color("85574b"))
	Geo.label(self, "SELLO", Vector3(1.53, 0.06, -0.61), 20, Color("b8c2ad"), 0.003)
	item_root = Node3D.new()
	item_root.name = "Interactivos"
	add_child(item_root)

func text_label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func panel_style(color: Color, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = border_color
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func make_button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(148, 44)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("eee5d0"))
	button.add_theme_stylebox_override("normal", panel_style(Color("29413f"), Color("53655a")))
	button.add_theme_stylebox_override("hover", panel_style(Color("415952"), Color("c9ba87")))
	button.add_theme_stylebox_override("pressed", panel_style(Color("182d2b")))
	button.pressed.connect(action)
	return button

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var heading := VBoxContainer.new()
	ui.add_child(heading)
	heading.position = Vector2(42, 30)
	heading.add_theme_constant_override("separation", 3)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(text_label("OFICINA CENTRAL     /     DEPARTAMENTO 01", 14, Color("c0b88e")))
	heading.add_child(text_label("Asuntos pendientes.", 36, Color("f3ecd9")))
	heading.add_child(text_label("Cada solicitud cuenta. Haz crecer tu oficina.", 16, Color("a6bab3")))
	var top_right := VBoxContainer.new()
	ui.add_child(top_right)
	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(1080, 36)
	top_right.size = Vector2(320, 100)
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := text_label("PRIMER TURNO  /  PROTOTIPO", 13, Color("c0b88e"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(badge)
	count_label = text_label("00 / 03  tramitados", 26, Color("f3ecd9"))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(count_label)
	var bottom := PanelContainer.new()
	ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 30
	bottom.offset_right = -30
	bottom.offset_top = -106
	bottom.offset_bottom = -22
	bottom.add_theme_stylebox_override("panel", panel_style(Color("172d2d"), Color("44574d")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bottom.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	prompt_label = text_label("Coge una solicitud de la bandeja izquierda", 20, Color("f2e8cc"))
	labels.add_child(prompt_label)
	status_label = text_label("CLIC IZQ  coger / dejar     ·     CLIC DER  sellar     ·     R  reponer mesa     ·     ESC  pausa", 14, Color("a9bbb1"))
	labels.add_child(status_label)
	row.add_child(make_button("Reponer  ·  R", reset_desk))
	row.add_child(make_button("Pausa  ·  Esc", toggle_pause))
	pause_panel = PanelContainer.new()
	ui.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -230
	pause_panel.offset_right = 230
	pause_panel.offset_top = -125
	pause_panel.offset_bottom = 125
	pause_panel.add_theme_stylebox_override("panel", panel_style(Color("172d2d"), Color("c9ba87")))
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 16)
	pause_panel.add_child(pause_box)
	pause_box.add_child(text_label("La oficina puede esperar.", 26, Color("f3ecd9")))
	pause_box.add_child(text_label("La mesa se conserva mientras haces una pausa.", 16, Color("a9bbb1")))
	pause_box.add_child(make_button("Continuar", toggle_pause))
	pause_box.add_child(make_button("Salir", func(): get_tree().quit()))
	pause_panel.hide()

func reset_desk() -> void:
	if automation:
		automation.cancel()
	if stroke and stroke.is_valid():
		stroke.kill()
	busy = false
	stroke_target = null
	held = null
	hovered = null
	for item in items:
		item_root.remove_child(item)
		item.queue_free()
	items.clear()
	for index in range(3):
		var paper := DeskItem.new()
		item_root.add_child(paper)
		paper.build("paper", progression.allocate_serial() if progression else index + 1)
		paper.position = Vector3(-3.55 + index * 0.12, 0.09 + index * 0.035, 0.36 - index * 0.28)
		items.append(paper)
	var stamp := DeskItem.new()
	item_root.add_child(stamp)
	stamp.build("stamp", 0)
	stamp.position = Vector3(1.53, 0.15, -1.16)
	items.append(stamp)
	message_time = 0.0
	set_paused(false)
	update_delivery()
	update_hint()
	if progression:
		progression.on_reset()

func _unhandled_input(event: InputEvent) -> void:
	if office and office.handle_input(event):
		return
	if progression and progression.overlay.visible:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			progression.close_shop()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			reset_desk()
		elif event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
	if paused:
		return
	if event is InputEventMouseMotion:
		cursor = event.position
		if held and not busy:
			move_held(cursor)
	if event is InputEventMouseButton and event.pressed:
		cursor = event.position
		if event.button_index == MOUSE_BUTTON_LEFT and not busy:
			if held:
				drop_item()
			else:
				var target: Node3D = pick_at(cursor)
				if target:
					pickup(target, cursor)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			try_stamp()

func _process(delta: float) -> void:
	if office and not office.at_desk:
		return
	if paused:
		return
	message_time = maxf(0, message_time - delta)
	var next: Node3D = null
	if not held and not get_viewport().gui_get_hovered_control():
		next = pick_at(cursor)
	if hovered != next:
		if is_instance_valid(hovered):
			hovered.set_highlight(false)
		hovered = next
		if hovered:
			hovered.set_highlight(true)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered or held else Input.CURSOR_ARROW)
	if message_time == 0:
		update_hint()

func plane_point(screen: Vector2, height: float) -> Vector3:
	var point: Variant = Plane(Vector3.UP, height).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	return point if point != null else Vector3.ZERO

func pick_at(screen: Vector2) -> Node3D:
	var best: Node3D
	var nearest := INF
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	for item in items:
		if item == held or (automation and automation.moving == item):
			continue
		var distance: float = item.ray_distance(origin, direction)
		if distance < nearest:
			nearest = distance
			best = item
	return best

func pickup(item: Node3D, screen: Vector2) -> void:
	if held or busy or paused or (automation and automation.moving == item):
		return
	held = item
	held.held = true
	# Lift along the viewing ray: the object stays at the same screen position.
	var center_screen := camera.unproject_position(item.global_position)
	item.global_position = plane_point(center_screen, 0.30 if item.kind == "paper" else 0.28)
	grab_offset = item.global_position - plane_point(screen, item.position.y)
	move_held(screen)
	item.set_highlight(true)
	update_delivery()
	update_hint()

func move_held(screen: Vector2) -> void:
	if not held or busy or paused:
		return
	var next := plane_point(screen, held.position.y) + grab_offset
	held.position.x = clampf(next.x, -TABLE_HALF.x + held.half_size.x, TABLE_HALF.x - held.half_size.x)
	held.position.z = clampf(next.z, -TABLE_HALF.y + held.half_size.y, TABLE_HALF.y - held.half_size.y)

func drop_item() -> void:
	if not held or busy or paused:
		return
	# Compact the finite stack before placing the lifted object on top.
	var papers: Array = items.filter(func(item): return item.kind == "paper" and item != held)
	papers.sort_custom(func(a, b): return a.position.y < b.position.y)
	for index in range(papers.size()):
		papers[index].position.y = 0.09 + index * 0.035
	var height: float = 0.09 + papers.size() * 0.035 if held.kind == "paper" else 0.09
	if held.kind == "stamp":
		for paper in papers:
			if paper.contains_footprint(held.position):
				height = maxf(height, paper.position.y + paper.hit_height)
		if absf(held.position.x - 1.53) < 0.5 and absf(held.position.z + 1.16) < 0.4:
			height = maxf(height, 0.15)
	held.position.y = height
	held.held = false
	held.set_highlight(false)
	held = null
	update_delivery()
	update_hint()
	if progression:
		progression.persist()
		progression.refresh()

func stamp_target() -> Node3D:
	if not held or held.kind != "stamp":
		return null
	var top: Node3D
	# Include partial footprint overlaps so a corner cannot stamp a hidden sheet.
	for item in items:
		if item.kind != "paper" or (automation and automation.moving == item):
			continue
		var local: Vector3 = item.to_local(held.global_position)
		if absf(local.x) < item.half_size.x + 0.26 and absf(local.z) < item.half_size.y + 0.17:
			if top == null or item.position.y > top.position.y:
				top = item
	if top and top.contains_footprint(held.global_position, Vector2(0.27, 0.18)):
		return top
	return null

func try_stamp() -> bool:
	if paused or busy or not held or held.kind != "stamp":
		return false
	var target := stamp_target()
	if not target:
		show_message("Coloca toda la base del sello dentro del papel.")
		return false
	busy = true
	stroke_target = target
	stamp_rest_y = held.position.y
	var stamp := held
	var point := held.global_position
	var duration: float = progression.economy.value(2, 0.27) / 0.27 if progression else 1.0
	stroke = create_tween()
	stroke.tween_property(stamp, "position:y", target.position.y + 0.026, 0.10 * duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	stroke.tween_callback(func():
		if is_instance_valid(target):
			target.add_impression(point)
			if progression:
				progression.persist()
			update_delivery()
	)
	stroke.tween_property(stamp, "position:y", stamp_rest_y, 0.17 * duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	stroke.tween_callback(func():
		busy = false
		stroke_target = null
		if progression:
			progression.refresh()
		show_message("Solicitud sellada. Déjala en la bandeja de salida.")
	)
	return true

func update_delivery() -> void:
	delivery_count = 0
	for item in items:
		if item.kind == "paper" and item != held and not item.impressions.is_empty() and not (automation and automation.moving == item):
			if item.position.x - item.half_size.x >= OUTPUT_X and absf(item.position.z) + item.half_size.y <= 1.83:
				delivery_count += 1
	count_label.text = "%02d / 03  en salida" % delivery_count
	if progression and is_instance_valid(progression.stats):
		progression.refresh()

func update_hint() -> void:
	if message_time > 0:
		return
	if delivery_count == 3:
		prompt_label.text = "Bandeja lista. Cobra la salida para recibir nuevas solicitudes."
	elif held and held.kind == "stamp":
		prompt_label.text = "Clic derecho para sellar  ·  Clic izquierdo para dejar el sello"
	elif held:
		prompt_label.text = "Lleva el documento al centro o a la salida y haz clic para dejarlo"
	elif hovered:
		prompt_label.text = "Clic para coger el sello" if hovered.kind == "stamp" else "Clic para coger la solicitud %03d" % hovered.serial
	else:
		prompt_label.text = "Coge el sello: el papel llega solo al centro y sale al sellarlo"

func show_message(value: String) -> void:
	prompt_label.text = value
	message_time = 3.0

func toggle_pause() -> void:
	set_paused(not paused)

func set_paused(value: bool) -> void:
	paused = value
	if office:
		office.sync_mouse()
	pause_panel.visible = value
	if stroke and stroke.is_valid():
		if value:
			stroke.pause()
		else:
			stroke.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(pause_panel):
		set_paused(true)
