extends ScrollContainer
const BRANCHES := ["Llegadas", "Almacenes", "Transporte", "Valor", "Sellado", "Ensobrado", "Envío", "Rutas"]
const LABELS := ["Precio base", "Multiplicador de venta", "Golpe manual (s)", "Papel en mesa (m/s)", "Llegada (s)", "Entrada sello", "Salida sello", "Entrada sobres", "Salida sobres", "Entrada envío", "Salida envío", "Carga jugador", "Jugador (m/s)", "Estación abierta", "Sellador", "Ensobrador", "Expedidor", "Ruta directa", "Ruta a sobres", "Ruta de sobres", "Sellador (s)", "Ensobrar (s)", "Preparar envío (s)", "Repartidor (m/s)", "Carga repartidor"]
const BASES := [100.0, 1.0, 0.27, 2.5, 5.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.4, 1.5, 1.2, 2.8, 2.0]
var progress: Node
var canvas: Control
var selected_branch := "Llegadas"
var nodes := {}

func setup(owner_progress: Node) -> void:
	progress = owner_progress
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(2560, 1800)
	add_child(canvas)

func rebuild() -> void:
	for child in canvas.get_children():
		canvas.remove_child(child)
		child.queue_free()
	nodes.clear()
	var desk = progress.desk
	for i in range(BRANCHES.size()):
		var label: Label = desk.text_label(BRANCHES[i].to_upper(), 21, Color("e5c67e"))
		canvas.add_child(label)
		label.position = Vector2(i * 320 + 12, 8)
	for entry in progress.economy.catalog.upgrades:
		var column := BRANCHES.find(entry.branch)
		var card := PanelContainer.new()
		card.position = Vector2(maxi(0, column) * 320 + 8, 52 + entry.tree_row * 280)
		card.size = Vector2(300, 260)
		var current: int = progress.economy.level(entry.id)
		var reason: String = progress.economy.reason(entry)
		var color := Color("81b48c") if current > 0 else Color("d0aa61") if reason.is_empty() else Color("52665e")
		card.add_theme_stylebox_override("panel", desk.panel_style(Color("203b36"), color))
		canvas.add_child(card)
		nodes[str(entry.id)] = card
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 5)
		card.add_child(col)
		var title: Label = desk.text_label("%s · %d/%d" % [entry.title, current, entry.max_level], 17, Color("f5e8c9"))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(title)
		var info: Label = desk.text_label(entry.description, 14, Color("b8ccbd"))
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(info)
		var preview := ""
		for effect in entry.effects:
			var a: int = effect.attribute
			if a == 0 or a == 1:
				preview += "Venta: %s → %s\n" % [progress.economy.money(progress.economy.payout()), progress.economy.money(progress.economy.payout(entry.id, mini(current + 1, entry.max_level)))]
			else:
				preview += "%s: %.2f → %.2f\n" % [LABELS[a], progress.economy.value(a, BASES[a]), progress.economy.value(a, BASES[a], entry.id, mini(current + 1, entry.max_level))]
		if entry.prerequisite != &"":
			preview += "↳ " + progress.economy.definition(entry.prerequisite).title
		if entry.required_sales > 0:
			preview += "\nDesbloqueo: %d ventas" % entry.required_sales
		var effect_label: Label = desk.text_label(preview.strip_edges(), 13, Color("e3c88d"))
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(effect_label)
		var button: Button = desk.make_button("Máximo" if current >= entry.max_level else progress.economy.money(progress.economy.cost(entry)), progress.purchase.bind(entry.id, current))
		button.disabled = not reason.is_empty() or not progress.store.writable
		button.tooltip_text = reason if not reason.is_empty() else "Comprar este nivel"
		col.add_child(button)
		var requirement: Label = desk.text_label(reason if not reason.is_empty() else "Disponible", 12, color)
		requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(requirement)
	# Edges are rendered below cards; cross-branch requirements also have explicit labels.
	for entry in progress.economy.catalog.upgrades:
		if entry.prerequisite == &"" or not nodes.has(str(entry.prerequisite)):
			continue
		var source: Control = nodes[str(entry.prerequisite)]
		var target: Control = nodes[str(entry.id)]
		if source.position.x != target.position.x:
			continue
		var line := Line2D.new()
		line.width = 2
		line.default_color = Color("9ea771")
		line.add_point(source.position + Vector2(150, 260))
		line.add_point(target.position + Vector2(150, -6))
		line.add_point(target.position + Vector2(145, -12))
		line.add_point(target.position + Vector2(150, -6))
		line.add_point(target.position + Vector2(155, -12))
		canvas.add_child(line)
		canvas.move_child(line, 0)
