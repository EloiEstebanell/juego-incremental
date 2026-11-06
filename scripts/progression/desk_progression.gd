extends Node
const Economy = preload("res://scripts/progression/economy.gd")
const SaveStore = preload("res://scripts/progression/save_store.gd")
const DeskItem = preload("res://scripts/desk_item.gd")
var desk: Node3D
var economy = Economy.new()
var store = SaveStore.new()
var persistence := true
var office_state := {"cargo": 0, "enveloped": false}
var network_state: Dictionary = {}
var tree_view: Control
var next_serial := 4
var overlay: ColorRect
var cards: VBoxContainer
var stats: Label
var shop_balance: Label
var save_status: Label
var collect_button: Button
var confirm: ConfirmationDialog
var refresh_pending := false
var last_purchase_msec := -1000

func setup(owner_desk: Node3D) -> void:
	desk = owner_desk
	var errors: PackedStringArray = economy.catalog.validate()
	if not errors.is_empty():
		store.writable = false
		store.notice = "Catálogo inválido: " + "; ".join(errors)
	elif persistence:
		var data := store.load_game()
		if not data.is_empty():
			economy.restore(data.economy)
			office_state = data.get("office", {"cargo": 0, "enveloped": false}).duplicate()
			network_state = data.get("network", {}).duplicate(true)
			next_serial = int(data.next_serial)
			restore_papers(data.papers)
	build_ui()
	if desk.items.size() == 1 and store.writable and not desk.stations_enabled:
		desk.reset_desk()
	refresh()
	if not store.notice.is_empty():
		save_status.text = store.notice
	else:
		save_status.text = "Guardado automático tras vender, comprar y mover documentos"

func restore_papers(records: Array) -> void:
	for item in desk.items.duplicate():
		if item.kind == "paper":
			desk.items.erase(item)
			desk.item_root.remove_child(item)
			item.queue_free()
	for record in records:
		var paper = DeskItem.new()
		desk.item_root.add_child(paper)
		paper.build("paper", int(record.serial))
		paper.position = Vector3(record.position[0], record.position[1], record.position[2])
		for mark in record.marks:
			paper.add_impression(paper.to_global(Vector3(mark[0], 0, mark[1])))
		desk.items.append(paper)
	desk.update_delivery()

func snapshot() -> Dictionary:
	var papers: Array = []
	for item in desk.items:
		if item.kind != "paper":
			continue
		var marks: Array = []
		for mark in item.impressions:
			marks.append([mark.x, mark.y])
		var saved_position: Vector3 = desk.automation.destination if desk.automation and desk.automation.moving == item else item.position
		papers.append({"serial": item.serial, "position": [saved_position.x, saved_position.y, saved_position.z], "marks": marks})
	return {"version": 3 if desk.stations_enabled else 2, "network": network_state.duplicate(true) if not network_state.is_empty() else preload("res://scripts/office/station_state.gd").fresh(), "economy": economy.snapshot(), "next_serial": next_serial, "papers": papers, "office": office_state.duplicate()}

func persist() -> bool:
	if not persistence:
		return true
	if not store.save(snapshot()):
		save_status.text = "No se pudo guardar. Conserva esta ventana abierta y revisa la carpeta saves."
		return false
	return true

func refresh() -> void:
	stats.text = "%s   ·   %d vendidos\n%s por documento" % [Economy.money(economy.balance), economy.sold, Economy.money(economy.payout())]
	collect_button.text = "Cobrar salida · " + Economy.money(economy.payout() * desk.delivery_count)
	if desk.stations:
		collect_button.text = "Recoger salida · llevar a envío"
	collect_button.disabled = desk.delivery_count == 0 or desk.busy or desk.held != null or not store.writable

func collect() -> void:
	if desk.stations:
		desk.stations.take_stamp_output()
		return
	if desk.paused or desk.busy or desk.held or not store.writable:
		return
	var candidates: Array = []
	for item in desk.items:
		if item.kind == "paper" and not item.impressions.is_empty() and item.position.x - item.half_size.x >= desk.OUTPUT_X and absf(item.position.z) + item.half_size.y <= 1.83 and not (desk.automation and desk.automation.moving == item):
			candidates.append(item)
	if candidates.is_empty():
		return
	var old_finance: Dictionary = economy.snapshot()
	var earned: int = economy.payout() * candidates.size()
	if economy.balance + earned > Economy.LIMIT or economy.sold + candidates.size() > 1000000000:
		desk.show_message("Límite del prototipo alcanzado.")
		return
	for paper in candidates:
		desk.items.erase(paper)
	economy.balance += earned
	economy.sold += candidates.size()
	# Commit the sale before deleting nodes: a failed write is fully reversible.
	if not persist():
		economy.restore(old_finance)
		desk.items.append_array(candidates)
		desk.show_message("Venta cancelada: no se pudo guardar. Tus documentos siguen en la mesa.")
		return
	for paper in candidates:
		if desk.hovered == paper:
			desk.hovered = null
		desk.item_root.remove_child(paper)
		paper.queue_free()
	desk.update_delivery()
	if desk.items.size() == 1:
		desk.reset_desk()
	refresh()
	desk.show_message("Entrega cobrada: +%s. Cada documento se vende una sola vez." % Economy.money(earned))

func purchase(id: StringName, expected_level: int) -> void:
	if refresh_pending or not store.writable or Time.get_ticks_msec() - last_purchase_msec < 400:
		return
	var old: Dictionary = economy.snapshot()
	if not economy.buy(id, expected_level):
		return
	if not persist():
		economy.restore(old)
		return
	last_purchase_msec = Time.get_ticks_msec()
	refresh_pending = true
	refresh_shop.call_deferred()
	refresh()

func allocate_serial() -> int:
	var serial := next_serial
	next_serial += 1
	return serial

func on_reset() -> void:
	persist()
	refresh()

func build_ui() -> void:
	stats = desk.text_label("", 18, Color("e1d9bb"))
	desk.ui.add_child(stats)
	stats.position = Vector2(650, 46)
	stats.size = Vector2(400, 60)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var shop_button: Button = desk.make_button("Árbol de mejoras · M", open_shop)
	desk.ui.add_child(shop_button)
	shop_button.position = Vector2(42, 142)
	collect_button = desk.make_button("Cobrar salida", collect)
	desk.ui.add_child(collect_button)
	collect_button.position = Vector2(1090, 142)
	collect_button.custom_minimum_size.x = 310
	save_status = desk.text_label("", 13, Color("c9ba87"))
	desk.ui.add_child(save_status)
	save_status.position = Vector2(350, 155)
	save_status.size = Vector2(700, 36)
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay = ColorRect.new()
	overlay.z_index = 10
	overlay.color = Color(0.025, 0.06, 0.06, 0.92)
	desk.ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -650
	panel.offset_right = 650
	panel.offset_top = -390
	panel.offset_bottom = 390
	panel.add_theme_stylebox_override("panel", desk.panel_style(Color("172d2d"), Color("8b9275")))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	content.add_child(desk.text_label("Árbol de mejoras", 32, Color("f3ecd9")))
	content.add_child(desk.text_label("Ramas independientes · las flechas y requisitos indican cada desbloqueo.", 17, Color("a9bbb1")))
	shop_balance = desk.text_label("", 19, Color("e3c98c"))
	content.add_child(shop_balance)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	cards = VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 12)
	scroll.add_child(cards)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	content.add_child(actions)
	actions.add_child(desk.make_button("Volver al juego · Esc", close_shop))
	actions.add_child(desk.make_button("Nueva partida…", func(): confirm.popup_centered()))
	confirm = ConfirmationDialog.new()
	confirm.title = "Empezar de nuevo"
	confirm.dialog_text = "Se reiniciarán el dinero, las mejoras y los documentos.\nSe conservará una copia de la partida anterior."
	confirm.ok_button_text = "Empezar de nuevo"
	confirm.cancel_button_text = "Cancelar"
	desk.ui.add_child(confirm)
	confirm.confirmed.connect(new_game)
	overlay.hide()

func open_shop() -> void:
	if desk.busy or desk.held:
		desk.show_message("Deja el objeto en la mesa antes de abrir las mejoras.")
		return
	desk.set_paused(true)
	desk.pause_panel.hide()
	overlay.show()
	refresh_shop()

func close_shop() -> void:
	overlay.hide()
	desk.set_paused(false)
	if desk.office and not desk.office.at_desk:
		desk.ui.hide()
		desk.office.walk_ui.show()
		desk.office.sync_mouse()

func refresh_shop() -> void:
	if desk.stations:
		refresh_pending = false
		shop_balance.text = "Saldo: " + Economy.money(economy.balance) + "   ·   %d cartas vendidas" % economy.sold
		cards.get_parent().hide()
		if not tree_view:
			tree_view = preload("res://scripts/progression/upgrade_tree.gd").new()
			cards.get_parent().get_parent().add_child(tree_view)
			cards.get_parent().get_parent().move_child(tree_view, 3)
			tree_view.setup(self)
			var branches := HBoxContainer.new()
			for i in range(tree_view.BRANCHES.size()):
				var branch_button: Button = desk.make_button(tree_view.BRANCHES[i], func(): tree_view.scroll_horizontal = i * 320)
				branch_button.custom_minimum_size = Vector2(0, 32)
				branch_button.add_theme_font_size_override("font_size", 13)
				branches.add_child(branch_button)
			cards.get_parent().get_parent().add_child(branches)
			cards.get_parent().get_parent().move_child(branches, 3)
		tree_view.rebuild()
		return
	shop_balance.text = "Saldo disponible: " + Economy.money(economy.balance)
	refresh_pending = false
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	for entry in economy.catalog.upgrades:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", desk.panel_style(Color("223c39"), Color("465c4e")))
		cards.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		card.add_child(row)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var current: int = economy.level(entry.id)
		words.add_child(desk.text_label("%s   ·   %d / %d" % [entry.title, current, entry.max_level], 23, Color("f3ecd9")))
		words.add_child(desk.text_label(entry.description, 16, Color("b6c5b8")))
		var preview := "Pago: %s → %s" % [Economy.money(economy.payout()), Economy.money(economy.payout(entry.id, mini(current + 1, entry.max_level)))]
		for effect in entry.effects:
			if effect.attribute == 2:
				preview += "   ·   Golpe: %.2f → %.2f s" % [economy.value(2, 0.27), economy.value(2, 0.27, entry.id, mini(current + 1, entry.max_level))]
			if effect.attribute == 3:
				preview += "   ·   Traslado: %.2f → %.2f s" % [3.55 / economy.value(3, 2.5), 3.55 / economy.value(3, 2.5, entry.id, mini(current + 1, entry.max_level))]
		words.add_child(desk.text_label(preview, 16, Color("d9c595")))
		var reason: String = economy.reason(entry)
		words.add_child(desk.text_label(reason if not reason.is_empty() else "Disponible", 14, Color("a9bbb1")))
		var button: Button = desk.make_button(Economy.money(economy.cost(entry)), purchase.bind(entry.id, current))
		button.disabled = not reason.is_empty() or not store.writable
		row.add_child(button)

func new_game() -> void:
	if desk.stations:
		desk.stations.new_game()
		return
	var fresh_papers: Array = []
	for index in range(3):
		fresh_papers.append({"serial": index + 1, "position": [-3.55 + index * 0.12, 0.09 + index * 0.035, 0.36 - index * 0.28], "marks": []})
	var fresh := {"version": 2, "office": {"cargo": 0, "enveloped": false}, "economy": {"balance": 0, "sold": 0, "levels": {}}, "next_serial": 4, "papers": fresh_papers}
	if persistence and (not store.allow_new_game() or not store.save(fresh)):
		save_status.text = "No se pudo guardar la nueva partida. Reinicio cancelado; se conserva tu progreso."
		return
	economy = Economy.new()
	office_state = {"cargo": 0, "enveloped": false}
	if desk.automation:
		desk.automation.cancel()
	if desk.office:
		desk.office.job_remaining = 0
	next_serial = 4
	restore_papers(fresh_papers)
	refresh_shop()
	refresh()
	close_shop()
	save_status.text = "Nueva partida. La anterior se conserva en la carpeta saves."
