extends Node
const Layout = preload("res://scripts/office/office_layout.gd")
const State = preload("res://scripts/office/station_state.gd")
const Paper = preload("res://scripts/desk_item.gd")
const Geo = preload("res://scripts/geometry.gd")
const Economy = preload("res://scripts/progression/economy.gd")
const CAP_ATTRIBUTES := {"stamp_in": 5, "stamp_out": 6, "envelope_in": 7, "envelope_out": 8, "shipping_in": 9, "shipping_out": 10}
const ROUTE_ATTRIBUTES := {"direct": 17, "envelope": 18, "shipping": 19}
var desk: Node3D
var progress: Node
var panel: Control
var panel_title: Label
var panel_info: Label
var buttons: Dictionary = {}
var current_station := "envelope"
var notice := ""
var autosave := 0.0
var overview: Label
var actors := {}
var signs := {}
var actor_labels := {}

func setup(owner_desk: Node3D) -> void:
	desk = owner_desk
	progress = desk.progression
	if progress.network_state.is_empty():
		progress.network_state = State.fresh()
	build_ui()
	build_actors()
	progress.refresh()

func data() -> Dictionary:
	return progress.network_state

func stat(attribute: int, base: float) -> float:
	return progress.economy.value(attribute, base)

func unlocked(attribute: int) -> bool:
	return stat(attribute, 0) >= 1

func capacity(key: String) -> int:
	return roundi(stat(CAP_ATTRIBUTES[key], 3))

func carry_capacity() -> int:
	return roundi(stat(11, 3))

func papers(output: bool) -> Array:
	return desk.items.filter(func(item): return item.kind == "paper" and not item.held and not (desk.automation and desk.automation.moving == item) and ((not item.impressions.is_empty() and desk.automation.in_output(item)) if output else (item.impressions.is_empty() and item.position.x < -1.4)))

func begin() -> Dictionary:
	return progress.snapshot()

func commit(before: Dictionary, changed_papers := false) -> bool:
	if progress.persist():
		progress.refresh()
		return true
	progress.economy.restore(before.economy)
	progress.office_state = before.office.duplicate(true)
	progress.network_state = before.network.duplicate(true)
	progress.next_serial = int(before.next_serial)
	if changed_papers:
		if desk.automation: desk.automation.cancel()
		desk.hovered = null
		progress.restore_papers(before.papers)
	notice = "No se pudo guardar. Operación cancelada; se conserva el material."
	return false

func can_change() -> bool:
	return progress.store.writable and not desk.paused

func remove_papers(items: Array) -> void:
	for paper in items:
		if desk.hovered == paper: desk.hovered = null
		desk.items.erase(paper)
		desk.item_root.remove_child(paper)
		paper.queue_free()
	desk.update_delivery()

func take_stamp_output() -> bool:
	if not can_change() or desk.busy or (desk.held and desk.held.kind == "paper") or progress.office_state.enveloped:
		return false
	var candidates: Array = papers(true).slice(0, maxi(0, carry_capacity() - int(progress.office_state.cargo)))
	if candidates.is_empty():
		notice = "Salida vacía o manos llenas."
		if desk.office: desk.office.tell(notice)
		return false
	var before := begin()
	progress.office_state.cargo += candidates.size()
	remove_papers(candidates)
	var ok := commit(before, true)
	if ok:
		notice = "Cartas recogidas. Llévalas a envío o ensobrado."
		if desk.office: desk.office.tell(notice)
	return ok

func reserved(destination: String) -> int:
	var count := 0
	for route in data().routes:
		var r: Dictionary = data().routes[route]
		if not r.returning and ((destination == "envelope" and route == "envelope") or (destination == "shipping" and route != "envelope")):
			count += int(r.cargo)
	return count

func input_count(station: String) -> int:
	return int(data().envelope_in) if station == "envelope" else int(data().shipping_in_raw + data().shipping_in_enveloped)

func output_count(station: String) -> int:
	return int(data().envelope_out) if station == "envelope" else int(data().shipping_out_raw + data().shipping_out_enveloped)

func input_room(station: String) -> int:
	return maxi(0, capacity(station + "_in") - input_count(station) - reserved(station))

func deposit(station: String) -> int:
	if not can_change() or (station == "envelope" and (not unlocked(13) or progress.office_state.enveloped)):
		return 0
	var amount := mini(int(progress.office_state.cargo), input_room(station))
	if amount <= 0:
		notice = "Sin cartas compatibles o entrada llena (incluidas las reservas)."
		return 0
	var before := begin()
	var key := "envelope_in" if station == "envelope" else "shipping_in_enveloped" if progress.office_state.enveloped else "shipping_in_raw"
	data()[key] += amount
	progress.office_state.cargo -= amount
	if progress.office_state.cargo == 0: progress.office_state.enveloped = false
	if not commit(before): return 0
	notice = "%d cartas depositadas. El sobrante permanece en tus manos." % amount
	return amount

func take_envelopes() -> int:
	if not can_change() or (progress.office_state.cargo > 0 and not progress.office_state.enveloped): return 0
	var amount := mini(int(data().envelope_out), carry_capacity() - int(progress.office_state.cargo))
	if amount <= 0: return 0
	var before := begin()
	data().envelope_out -= amount
	progress.office_state.cargo += amount
	progress.office_state.enveloped = true
	return amount if commit(before) else 0

func task_duration(station: String) -> float:
	return stat(21, 1.5) if station == "envelope" else stat(22, 1.2)

func start_task(station: String) -> bool:
	if not can_change() or (station == "envelope" and not unlocked(13)) or data()[station + "_job"] > 0:
		return false
	if input_count(station) == 0 or output_count(station) >= capacity(station + "_out"):
		notice = "Esperando: entrada vacía o salida llena."
		return false
	var before := begin()
	data()[station + "_job"] = task_duration(station)
	return commit(before)

func finish_task(station: String) -> bool:
	if input_count(station) == 0 or output_count(station) >= capacity(station + "_out"): return false
	var before := begin()
	if station == "envelope":
		data().envelope_in -= 1
		data().envelope_out += 1
	else:
		var suffix := "enveloped" if data().shipping_in_enveloped > 0 else "raw"
		data()["shipping_in_" + suffix] -= 1
		data()["shipping_out_" + suffix] += 1
	data()[station + "_job"] = 0.0
	return commit(before)

func dispatch() -> bool:
	if not can_change() or output_count("shipping") == 0: return false
	var before := begin()
	var count := output_count("shipping")
	var earned: int = progress.economy.payout() * int(data().shipping_out_raw + 2 * data().shipping_out_enveloped)
	if progress.economy.balance + earned > Economy.LIMIT or progress.economy.sold + count > 1000000000: return false
	progress.economy.balance += earned
	progress.economy.sold += count
	data().shipping_out_raw = 0
	data().shipping_out_enveloped = 0
	if not commit(before): return false
	notice = "Enviado: +" + Economy.money(earned)
	return true

func receive_letter() -> bool:
	if desk.items.size() - 1 >= capacity("stamp_in") + capacity("stamp_out") + 1: return false
	if papers(false).size() >= capacity("stamp_in") or not can_change() or desk.busy or (desk.held and desk.held.kind == "paper"): return false
	if progress.next_serial >= 1000000000: return false
	var before := begin()
	var paper := Paper.new()
	desk.item_root.add_child(paper)
	paper.build("paper", progress.allocate_serial())
	paper.position = Vector3(-3.55, 0.09 + papers(false).size() * 0.025, 0)
	desk.items.append(paper)
	data().arrival_clock = 0.0
	return commit(before, true)

func advance(delta: float) -> void:
	if not can_change(): return
	data().arrival_clock = minf(stat(4, 5.0), data().arrival_clock + delta)
	if data().arrival_clock >= stat(4, 5.0): receive_letter()
	for station in ["envelope", "shipping"]:
		var key: String = station + "_job"
		if data()[key] > 0:
			data()[key] = maxf(0.001, data()[key] - delta)
			if data()[key] <= 0.001: finish_task(station)
		elif unlocked(15 if station == "envelope" else 16):
			start_task(station)
	if unlocked(16):
		data().dispatch_clock = minf(4.0, data().dispatch_clock + delta)
		if data().dispatch_clock >= 4.0:
			if dispatch(): data().dispatch_clock = 0.0
	advance_stamp(delta)
	# Envelope route has priority when both routes could collect the same papers.
	for route in ["envelope", "direct", "shipping"]:
		if data().routes.has(route):
			var r: Dictionary = data().routes[route]
			r.time = maxf(0, r.time - delta)
			if r.time <= 0: arrive(route)
		elif unlocked(ROUTE_ATTRIBUTES[route]):
			start_route(route)
	autosave += delta
	if autosave >= 5:
		autosave = 0
		progress.persist()

func advance_stamp(delta: float) -> void:
	if not unlocked(14) or desk.busy or desk.held: return
	var target: Node3D
	for paper in desk.items:
		if paper.kind == "paper" and paper.impressions.is_empty() and absf(paper.position.x) < 1.0 and not (desk.automation and desk.automation.moving == paper):
			target = paper
	if target == null or papers(true).size() >= capacity("stamp_out"):
		data().stamp_clock = 0.0
		return
	data().stamp_clock += delta
	if data().stamp_clock >= stat(20, 2.4):
		var before := begin()
		target.add_impression(target.global_position)
		data().stamp_clock = 0.0
		commit(before, true)

func route_points(route: String) -> Array[Vector3]:
	# Waypoints run through the side aisles, outside the desk collision footprint.
	if route == "envelope": return [Layout.PICKUP, Vector3(2, -1.04, 1.15), Vector3(2, -1.04, -1.7), Layout.ENVELOPES]
	if route == "shipping": return [Layout.ENVELOPES, Layout.SHIPPING]
	return [Layout.PICKUP, Vector3(-2, -1.04, 1.15), Vector3(-2, -1.04, -1.7), Layout.SHIPPING]

func route_length(route: String) -> float:
	var points := route_points(route)
	var distance := 0.0
	for i in range(1, points.size()): distance += points[i - 1].distance_to(points[i])
	return distance

func start_route(route: String) -> bool:
	if not can_change() or not unlocked(ROUTE_ATTRIBUTES[route]) or data().routes.has(route): return false
	if route == "direct" and not data().direct_enabled: return false
	if route != "direct" and not unlocked(13): return false
	if desk.busy or (desk.held and desk.held.kind == "paper"): return false
	var destination := "envelope" if route == "envelope" else "shipping"
	var available: int = int(data().envelope_out) if route == "shipping" else papers(true).size()
	var count := mini(available, mini(input_room(destination), roundi(stat(24, 2))))
	if count <= 0: return false
	var before := begin()
	var seconds := route_length(route) / stat(23, 2.8)
	data().routes[route] = {"cargo": count, "time": seconds, "duration": seconds, "returning": false}
	if route == "shipping": data().envelope_out -= count
	else: remove_papers(papers(true).slice(0, count))
	return commit(before, route != "shipping")

func arrive(route: String) -> bool:
	var before := begin()
	var r: Dictionary = data().routes[route]
	if r.returning:
		data().routes.erase(route)
	else:
		var key := "envelope_in" if route == "envelope" else "shipping_in_enveloped" if route == "shipping" else "shipping_in_raw"
		data()[key] += int(r.cargo)
		r.cargo = 0
		r.returning = true
		r.duration = route_length(route) / stat(23, 2.8)
		r.time = r.duration
	return commit(before)

func _process(delta: float) -> void:
	advance(delta)
	update_visuals()
	if panel.visible: refresh_panel()

func tidy() -> void:
	if desk.busy or desk.paused: return
	if desk.held: desk.drop_item()
	if desk.automation: desk.automation.cancel()
	var inputs := 0
	var outputs := 0
	for item in desk.items:
		if item.kind == "stamp": item.position = Vector3(1.53, 0.15, -1.16)
		elif item.impressions.is_empty():
			item.position = Vector3(-3.55, 0.09 + mini(inputs, 24) * 0.025, 0)
			inputs += 1
		else:
			# Overflow remains in the work area, never manufactured or deleted.
			item.position = Vector3(3.55 if outputs < capacity("stamp_out") else 0, 0.09 + mini(outputs, 24) * 0.025, 0)
			outputs += 1
	desk.update_delivery()
	progress.persist()
	desk.show_message("Mesa ordenada. Las cartas nuevas llegan con el tiempo.")

func new_game() -> void:
	var fresh := {"version": 3, "economy": {"balance": 0, "sold": 0, "levels": {}}, "office": {"cargo": 0, "enveloped": false}, "network": State.fresh(), "next_serial": 4, "papers": []}
	for i in range(3): fresh.papers.append({"serial": i + 1, "position": [-3.55, 0.09 + i * 0.025, 0], "marks": []})
	if progress.persistence and (not progress.store.allow_new_game() or not progress.store.save(fresh)): return
	progress.economy.restore(fresh.economy)
	progress.office_state = fresh.office
	progress.network_state = fresh.network
	progress.next_serial = 4
	desk.automation.cancel()
	progress.restore_papers(fresh.papers)
	progress.refresh_shop()
	progress.refresh()
	progress.close_shop()

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if panel.visible and event.physical_keycode in [KEY_ESCAPE, KEY_E]:
			close_station()
			return true
		if event.physical_keycode == KEY_M and not panel.visible:
			if progress.overlay.visible: progress.close_shop()
			elif not desk.busy and not desk.held:
				desk.ui.show()
				if desk.office: desk.office.walk_ui.hide()
				progress.open_shop()
			return true
	if panel.visible: return true
	return false

func build_ui() -> void:
	overview = desk.text_label("", 15, Color("e6d9b0"))
	var info_panel := PanelContainer.new()
	desk.ui.add_child(info_panel)
	info_panel.position = Vector2(380, 202)
	info_panel.add_theme_stylebox_override("panel", desk.panel_style(Color("172d2d"), Color("53655a")))
	info_panel.add_child(overview)
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	panel = ColorRect.new()
	panel.color = Color(0.025, 0.06, 0.055, 0.93)
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	panel.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -420
	card.offset_right = 420
	card.offset_top = -300
	card.offset_bottom = 300
	card.add_theme_stylebox_override("panel", desk.panel_style(Color("172d2d"), Color("9ea97a")))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	panel_title = desk.text_label("", 30, Color("f5e8c9"))
	col.add_child(panel_title)
	panel_info = desk.text_label("", 19, Color("d6d8be"))
	panel_info.custom_minimum_size.y = 190
	panel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(panel_info)
	for key in ["deposit", "work", "take", "dispatch", "route"]:
		var button: Button = desk.make_button("", panel_action.bind(key))
		buttons[key] = button
		col.add_child(button)
	col.add_child(desk.make_button("Volver a la oficina · E / Esc", close_station))
	panel.hide()

func panel_action(action: String) -> void:
	match action:
		"deposit": deposit(current_station)
		"work": start_task(current_station)
		"take": take_envelopes()
		"dispatch": dispatch()
		"route":
			var before := begin()
			data().direct_enabled = not data().direct_enabled
			commit(before)
	refresh_panel()

func open_station(station: String) -> void:
	current_station = station
	notice = ""
	panel.show()
	desk.office.sync_mouse()
	refresh_panel()

func close_station() -> void:
	panel.hide()
	if desk.office: desk.office.sync_mouse()

func station_status(station: String) -> String:
	if station == "envelope" and not unlocked(13): return "Bloqueada: compra Abrir ensobrado en el árbol (M)."
	if data()[station + "_job"] > 0: return "Trabajando · %.1f s" % data()[station + "_job"]
	if input_count(station) == 0: return "Esperando cartas en la entrada"
	if output_count(station) >= capacity(station + "_out"): return "Salida llena: retira o despacha las cartas"
	return "Lista para trabajar"

func refresh_panel() -> void:
	var is_envelope := current_station == "envelope"
	var locked := is_envelope and not unlocked(13)
	panel_title.text = "03 / ENSOBRADO" if is_envelope else "02 / ENVÍO"
	panel_info.text = "Entrada: %d / %d   ·   Reservadas en camino: %d\nSalida: %d / %d   ·   Carga: %d / %d\n%s\n%s\n%s" % [input_count(current_station), capacity(current_station + "_in"), reserved(current_station), output_count(current_station), capacity(current_station + "_out"), progress.office_state.cargo, carry_capacity(), station_status(current_station), "Los sobres se venden por " + Economy.money(progress.economy.payout() * 2) if is_envelope else "Sellada: %s · Sobre: %s · Saldo: %s" % [Economy.money(progress.economy.payout()), Economy.money(progress.economy.payout() * 2), Economy.money(progress.economy.balance)], notice]
	buttons.deposit.text = "Depositar cartas en la entrada"
	buttons.deposit.disabled = locked or progress.office_state.cargo == 0 or input_room(current_station) == 0 or (is_envelope and progress.office_state.enveloped)
	buttons.work.text = "Ensobrar una carta · %.2f s" % task_duration(current_station) if is_envelope else "Preparar un envío · %.2f s" % task_duration(current_station)
	buttons.work.disabled = locked or data()[current_station + "_job"] > 0 or input_count(current_station) == 0 or output_count(current_station) >= capacity(current_station + "_out")
	buttons.take.text = "Recoger sobres de la salida"
	buttons.take.visible = is_envelope
	buttons.take.disabled = locked or data().envelope_out == 0 or progress.office_state.cargo >= carry_capacity() or (progress.office_state.cargo > 0 and not progress.office_state.enveloped)
	buttons.dispatch.text = "Despachar salida y cobrar"
	buttons.dispatch.visible = not is_envelope
	buttons.dispatch.disabled = output_count("shipping") == 0
	buttons.route.visible = not is_envelope and unlocked(17)
	buttons.route.text = "Ruta directa: " + ("activa · pulsar para pausar" if data().direct_enabled else "pausada · pulsar para activar")

func update_walk_hud() -> void:
	var office = desk.office
	var cargo: int = progress.office_state.cargo
	office.carried_visual.visible = cargo > 0
	for i in range(office.carried_visual.get_child_count()): office.carried_visual.get_child(i).visible = i < cargo
	office.ledger.text = "Carga: %d / %d · %s · %s" % [cargo, carry_capacity(), "sobres" if progress.office_state.enveloped else "cartas selladas", Economy.money(progress.economy.balance)]
	if office.message_time > 0:
		office.hint.text = office.message
		return
	match office.nearest_station():
		"desk": office.hint.text = "E · Sentarse a sellar   |   M · Árbol de mejoras"
		"pickup": office.hint.text = "E · Recoger salida del sello (%d disponibles)   |   M · Mejoras" % papers(true).size()
		"envelopes": office.hint.text = "E · Estación 03: ensobrado   |   " + station_status("envelope")
		"shipping": office.hint.text = "E · Estación 02: envío y venta   |   " + station_status("shipping")
		_: office.hint.text = "Envío: fondo izquierda · Ensobrado: fondo derecha · M: mejoras"

func build_actors() -> void:
	if not desk.office: return
	for key in ["stamp", "envelope", "shipping", "direct_route", "envelope_route", "shipping_route"]:
		var actor := Node3D.new()
		desk.office.world.add_child(actor)
		Geo.cylinder(actor, 0.22, 0.75, Vector3(0, 0.72, 0), Color("496f82") if key.ends_with("route") else Color("9e7350"))
		Geo.cylinder(actor, 0.16, 0.30, Vector3(0, 1.25, 0), Color("d9b28b"))
		Geo.box(actor, Vector3(0.34, 0.12, 0.42), Vector3(0, 0.87, -0.25), Color("dfd5b1"))
		actors[key] = actor
		var label := Geo.label(actor, "", Vector3(0, 1.65, 0), 18, Color("fff0cd"), 0.004)
		label.rotation_degrees.x = 0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor_labels[key] = label
	for station in ["envelope", "shipping"]:
		var label := Geo.label(desk.office.world, "", Vector3(3.0 if station == "envelope" else -3.0, 0.20, -2.85), 17, Color("edf0ce"), 0.005)
		label.rotation_degrees.x = 0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		signs[station] = label

func route_position(route: String, fraction: float) -> Vector3:
	var points := route_points(route)
	var remaining := route_length(route) * clampf(fraction, 0, 1)
	for i in range(1, points.size()):
		var length := points[i - 1].distance_to(points[i])
		if remaining <= length: return points[i - 1].lerp(points[i], remaining / length)
		remaining -= length
	return points[-1]

func update_visuals() -> void:
	overview.text = "Llegada: %.1f s · Entrada %d/%d · Carga %d/%d\n%s" % [maxf(0, stat(4, 5.0) - data().arrival_clock), papers(false).size(), capacity("stamp_in"), progress.office_state.cargo, carry_capacity(), "Entrada llena: recepción detenida" if papers(false).size() >= capacity("stamp_in") else "Sella → recoge → lleva a envío · M: árbol de mejoras"]
	if not desk.office: return
	for station in signs:
		signs[station].text = "%d/%d → %d/%d\n%s" % [input_count(station), capacity(station + "_in"), output_count(station), capacity(station + "_out"), station_status(station)]
	for station in ["stamp", "envelope", "shipping"]:
		actors[station].visible = unlocked({"stamp": 14, "envelope": 15, "shipping": 16}[station])
		actor_labels[station].text = ("Sellador · esperando" if data().stamp_clock == 0 else "Sellando…") if station == "stamp" else station_status(station)
		actors[station].position = {"stamp": Vector3(0, -1.04, -1.0), "envelope": Vector3(4.15, -1.04, -2.3), "shipping": Vector3(-4.15, -1.04, -2.3)}[station]
	for route in ROUTE_ATTRIBUTES:
		var actor: Node3D = actors[route + "_route"]
		actor.visible = unlocked(ROUTE_ATTRIBUTES[route])
		var fraction := 0.0
		actor_labels[route + "_route"].text = "Repartidor · espera material o espacio"
		if route == "direct" and not data().direct_enabled: actor_labels[route + "_route"].text = "Ruta directa pausada"
		if data().routes.has(route):
			var r: Dictionary = data().routes[route]
			fraction = 1.0 - float(r.time) / float(r.duration)
			if r.returning: fraction = 1.0 - fraction
			actor_labels[route + "_route"].text = "Regresando" if r.returning else "Transportando %d cartas" % r.cargo
		actor.position = route_position(route, fraction)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and progress and progress.store.writable:
		progress.persist()
