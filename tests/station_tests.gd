extends SceneTree
const Progression = preload("res://scripts/progression/desk_progression.gd")
const Network = preload("res://scripts/office/station_network.gd")
const State = preload("res://scripts/office/station_state.gd")
var desk: Node3D
var n: Node
var p: Node
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func equivalent(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	return a == b
func total() -> int:
	var count: int = desk.items.size() - 1 + int(p.office_state.cargo) + p.economy.sold
	for key in ["envelope_in", "envelope_out", "shipping_in_raw", "shipping_in_enveloped", "shipping_out_raw", "shipping_out_enveloped"]: count += int(n.data()[key])
	for route in n.data().routes.values(): count += int(route.cargo)
	return count
func stamp_all() -> void:
	desk.automation.cancel()
	for paper in desk.items:
		if paper.kind == "paper":
			paper.position = Vector3(3.55, 0.1, 0)
			if paper.impressions.is_empty(): paper.add_impression(paper.global_position)
	desk.update_delivery()
func run() -> void:
	desk = load("res://scenes/desk.tscn").instantiate()
	desk.progression_enabled = false
	root.add_child(desk)
	p = Progression.new()
	p.persistence = false
	desk.progression = p
	desk.add_child(p)
	p.setup(desk)
	n = Network.new()
	desk.stations = n
	desk.add_child(n)
	n.setup(desk)
	n.set_process(false)
	desk.automation.set_process(false)
	desk.set_paused(false)
	check(p.economy.catalog.validate().is_empty(), "25 resource upgrades validate")
	check(p.economy.catalog.upgrades.size() == 25, "Catalog includes every independent branch")
	check(not n.unlocked(13) and not n.start_task("envelope"), "Enveloping is locked initially")
	check(n.capacity("stamp_in") == 3 and n.capacity("shipping_out") == 3, "Each station starts with independent bounded trays")
	n.advance(20)
	check(desk.items.size() == 4, "Full input blocks arrivals without backlog burst")
	desk.automation.advance(0)
	desk.automation.advance(10)
	check(n.receive_letter() and desk.items.size() == 5, "Moving one paper to work frees an arrival slot")
	var before: int = desk.items.size()
	desk.reset_desk()
	check(desk.items.size() == before, "Ordering desk neither creates nor deletes letters")
	p.economy.balance = 100000
	check(p.economy.buy(&"arrival_rate", 0) and is_equal_approx(n.stat(4, 5), 4.0), "Arrival upgrade changes actual interval")
	check(p.economy.buy(&"stamp_input", 0) and n.capacity("stamp_in") == 6 and n.capacity("stamp_out") == 3, "Input storage does not silently upgrade output")
	check(p.economy.buy(&"carry_capacity", 0) and n.carry_capacity() == 5, "Player carrying capacity upgrades independently")
	check(not p.economy.buy(&"envelope_station", 0), "Enveloping has a sales unlock in addition to price")
	p.economy.sold = 10
	check(p.economy.buy(&"envelope_station", 0) and n.unlocked(13), "Station unlock activates its actual operations")
	check(not p.economy.buy(&"stamp_employee", 0) and p.economy.buy(&"shipping_employee", 0), "Hiring thresholds are distinct")
	stamp_all()
	check(n.take_stamp_output() and p.office_state.cargo == 4 and desk.items.size() == 1, "Manual pickup respects upgraded capacity without replenishment")
	check(n.deposit("envelope") == 3 and p.office_state.cargo == 1 and n.data().envelope_in == 3, "Partial deposit retains excess in hands")
	check(n.start_task("envelope"), "Manual station starts a timed operation")
	var job: float = n.data().envelope_job
	desk.set_paused(true)
	n.advance(10)
	check(n.data().envelope_job == job, "Pause freezes production, arrivals and transport")
	desk.set_paused(false)
	n.advance(1.6)
	check(n.data().envelope_out == 1 and n.data().envelope_in == 2, "Enveloping transforms exactly one input into one output")
	check(n.take_envelopes() == 0, "Raw and enveloped cargo cannot mix in player hands")
	check(n.deposit("shipping") == 1 and p.office_state.cargo == 0, "Raw letters can bypass enveloping")
	check(n.take_envelopes() == 1 and p.office_state.enveloped, "Finished envelope can be collected")
	check(n.deposit("envelope") == 0, "Envelope cannot be enveloped twice")
	check(n.deposit("shipping") == 1 and n.input_count("shipping") == 2, "Shipping stores raw and enveloped letters together with type retained")
	p.economy.levels.erase("shipping_employee")
	check(n.start_task("shipping"), "Manual shipping prepares an input")
	n.advance(1.3)
	var balance: int = p.economy.balance
	check(n.data().shipping_out_enveloped == 1 and p.economy.balance == balance, "Preparing an envelope does not sell it early")
	check(n.dispatch() and p.economy.balance == balance + 200, "Dispatch pays double exactly once")
	check(not n.dispatch(), "Repeated dispatch cannot duplicate income")
	n.data().envelope_out = n.capacity("envelope_out")
	check(not n.start_task("envelope"), "Full output blocks work before consuming input")
	n.data().envelope_out = 0
	# All three transporters can compete with player deposits: reserve destination first.
	p.economy.sold = 30
	check(p.economy.buy(&"direct_courier", 0) and p.economy.buy(&"envelope_courier", 0) and p.economy.buy(&"shipping_courier", 0), "Routes are separately hired")
	for i in range(5): n.receive_letter()
	stamp_all()
	n.data().envelope_in = 0
	n.data().shipping_in_raw = 0
	n.data().shipping_in_enveloped = 0
	var quantity := total()
	check(n.start_route("envelope") and n.reserved("envelope") == 2, "Courier takes ownership and reserves destination")
	check(n.start_route("direct") and n.reserved("shipping") == 2, "Separate courier owns a different batch")
	p.office_state = {"cargo": 2, "enveloped": false}
	quantity += 2
	check(n.deposit("envelope") == 1 and p.office_state.cargo == 1, "Player cannot occupy courier's reserved space")
	check(total() == quantity, "Pickup and reservation conserve total material")
	check(n.arrive("envelope") and n.data().envelope_in == 3 and n.reserved("envelope") == 0, "Arrival consumes reservation without exceeding capacity")
	check(n.data().routes.envelope.returning and n.data().routes.envelope.cargo == 0, "Courier returns empty after delivery")
	check(n.arrive("envelope") and not n.data().routes.has("envelope") and total() == quantity, "Return leg does not duplicate cargo")
	var path := "res://tests/.tmp/stations-" + str(Time.get_ticks_usec())
	p.store.path = path + "/save.json"
	p.persistence = true
	check(p.persist(), "Schema 3 saves queues and in-flight routes")
	var loaded: Dictionary = p.store.load_game()
	check(loaded.version == 3 and loaded.network.routes.direct.cargo == 2 and loaded.office.cargo == 1, "Reload preserves courier cargo, reservation and player cargo")
	var bad: Dictionary = loaded.duplicate(true)
	bad.network.routes.direct.cargo = -1
	check(not p.store.valid(bad), "Corrupt transport quantity is rejected")
	bad = loaded.duplicate(true)
	bad.network.shipping_in_raw = 1.5
	check(not p.store.valid(bad), "Fractional letters rejected")
	p.store.path = path
	var before_failure := total()
	var input_before: int = n.input_count("shipping")
	check(not n.arrive("direct") and total() == before_failure and n.input_count("shipping") == input_before and n.data().routes.direct.cargo == 2, "Failed delivery save restores both cargo and reservation")
	n.data().shipping_out_raw = 2
	balance = p.economy.balance
	check(not n.dispatch() and n.data().shipping_out_raw == 2 and p.economy.balance == balance, "Failed sale save restores letters and money")
	p.store.path = path + "/save.json"
	p.persistence = false
	# Run the complete automated chain for ten simulated minutes; count arrivals independently.
	n.data().routes.clear()
	p.network_state = State.fresh()
	p.office_state = {"cargo": 0, "enveloped": false}
	n.remove_papers(desk.items.filter(func(item): return item.kind == "paper"))
	p.economy.sold = 0
	p.economy.balance = 0
	for id in ["stamp_employee", "envelope_employee", "shipping_employee"]: p.economy.levels[id] = 1
	n.data().direct_enabled = false
	var received := 0
	for i in range(6000):
		var serial: int = p.next_serial
		n.advance(0.1)
		desk.automation.advance(0.1)
		received += p.next_serial - serial
	check(p.economy.sold > 20, "Three workers and two couriers sustain the complete automated chain")
	check(total() == received, "Ten minutes conserve every generated letter across all queues, hands, routes and sales")
	check(p.economy.balance == p.economy.sold * 200, "Enveloped automation receives double payment for every sold letter")
	check(n.input_count("shipping") + n.reserved("shipping") <= n.capacity("shipping_in") and n.input_count("envelope") + n.reserved("envelope") <= n.capacity("envelope_in"), "Long-running routes never overbook destination capacity")
	# UI actually exposes nodes and prevents the station panel from controlling movement.
	p.open_shop()
	await process_frame
	await process_frame
	check(p.tree_view.nodes.size() == 25 and desk.paused, "Improvement tree shows all 25 nodes while paused")
	p.close_shop()
	desk.office.leave_desk()
	n.open_station("shipping")
	check(n.panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Station opens an interactive panel with released mouse")
	n.close_station()
	check(not n.panel.visible and not desk.office.at_desk and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"), "Closing panel restores first-person controls")
	# Recreate an actual scene from a schema-3 save, including reserved cargo.
	p.persistence = true
	p.store.path = path + "/reload.json"
	check(p.persist(), "Advanced office snapshot passes capacity validation")
	var before_reload := total()
	var saved_network: Dictionary = n.data().duplicate(true)
	var reloaded_desk = load("res://scenes/desk.tscn").instantiate()
	reloaded_desk.progression_enabled = false
	root.add_child(reloaded_desk)
	var reloaded_progress = Progression.new()
	reloaded_progress.store.path = p.store.path
	reloaded_desk.progression = reloaded_progress
	reloaded_desk.add_child(reloaded_progress)
	reloaded_progress.setup(reloaded_desk)
	var reloaded_network = Network.new()
	reloaded_desk.stations = reloaded_network
	reloaded_desk.add_child(reloaded_network)
	reloaded_network.setup(reloaded_desk)
	reloaded_network.set_process(false)
	reloaded_desk.automation.set_process(false)
	check(equivalent(reloaded_progress.network_state, saved_network) and reloaded_progress.economy.sold == p.economy.sold, "Actual scene reload restores all station queues and route timers")
	reloaded_desk.queue_free()
	await process_frame
	desk.set_paused(false)
	check(total() == before_reload, "Independent reload leaves running original untouched")
	var legacy := {"version": 2, "economy": {"balance": 1234, "sold": 7, "levels": {"paper_transport": 1}}, "office": {"cargo": 3, "enveloped": true}, "next_serial": 4, "papers": []}
	p.store.path = path + "/legacy.json"
	check(p.store.save(legacy), "Legacy schema-2 fixture writes")
	var migrated: Dictionary = p.store.load_game()
	check(migrated.version == 3 and migrated.office.cargo == 3 and migrated.office.enveloped and migrated.economy.balance == 1234 and migrated.economy.levels.paper_transport == 1, "Migration preserves old cargo, bonus, money and stable upgrade IDs")
	p.store.path = path + "/manual.json"
	desk.office.sit_down()
	n.new_game()
	check(p.economy.sold == 0 and p.economy.levels.is_empty() and n.data().routes.is_empty() and desk.items.size() == 4, "New game clears workers, routes, queues and timers atomically")
	desk.automation.advance(0)
	desk.automation.advance(10)
	var stamp: Node3D = desk.items.filter(func(item): return item.kind == "stamp")[0]
	desk.pickup(stamp, desk.camera.unproject_position(stamp.position))
	stamp.position = Vector3(0, 0.28, 0)
	check(desk.try_stamp(), "Actual manual stamp works with all three stations enabled")
	await create_timer(0.4).timeout
	desk.set_paused(false)
	desk.automation.advance(0)
	desk.automation.advance(10)
	desk.drop_item()
	check(n.take_stamp_output() and n.deposit("shipping") == 1 and n.start_task("shipping"), "Manually stamped letter travels from desk into shipping task")
	n.advance(1.3)
	check(n.dispatch() and p.economy.sold == 1 and p.economy.balance == 100, "Complete manual first sale works with locked enveloping and no employees")
	check(p.store.load_game().economy.sold == 1, "Complete manual sale is durable")
	# Courier upgrades require any hire, without forcing a purchase of the direct route.
	p.economy.balance = 100000
	p.economy.sold = 30
	check(not p.economy.buy(&"courier_speed", 0), "Courier speed requires a hire")
	p.economy.buy(&"envelope_station", 0)
	p.economy.buy(&"envelope_courier", 0)
	check(p.economy.buy(&"courier_speed", 0) and p.economy.level(&"direct_courier") == 0 and is_equal_approx(n.stat(23, 2.8), 3.5), "Hiring envelope courier unlocks transport speed without direct route")
	check(p.economy.buy(&"envelope_work_speed", 0) and is_equal_approx(n.task_duration("envelope"), 1.2), "Task speed changes independently of route speed")
	check(p.economy.buy(&"shipping_output", 0) and n.capacity("shipping_out") == 6 and n.capacity("shipping_in") == 3, "Shipping input and output upgrades are separate")
	var invalid_capacity: Dictionary = p.snapshot()
	invalid_capacity.network.envelope_in = 4
	check(not p.store.valid(invalid_capacity), "Overbooked saved input is rejected")
	p.open_shop()
	await process_frame
	await process_frame
	p.last_purchase_msec = -1000
	var card: Control = p.tree_view.nodes["arrival_rate"]
	var buy_button: Button = card.get_child(0).get_child(3)
	var old_level: int = p.economy.level(&"arrival_rate")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = buy_button.get_global_rect().get_center()
	mouse.pressed = true
	root.push_input(mouse, true)
	mouse = mouse.duplicate()
	mouse.pressed = false
	root.push_input(mouse, true)
	await process_frame
	check(p.economy.level(&"arrival_rate") == old_level + 1, "Real upgrade-tree button purchases its visible node")
	p.close_shop()
	var startup = load("res://scenes/desk.tscn").instantiate()
	startup.save_path = path + "/startup.json"
	root.add_child(startup)
	startup.stations.set_process(false)
	startup.automation.set_process(false)
	check(startup.progression != null and startup.stations != null and startup.office != null and startup.progression.snapshot().version == 3, "Unmodified scene startup wires all three stations and schema 3")
	startup.set_paused(false)
	startup.progression.economy.levels["shipping_employee"] = 1
	startup.stations.advance(901)
	check(startup.stations.data().dispatch_clock == 4.0 and startup.progression.persist(), "Long idle shipping wait remains bounded and saveable")
	startup.queue_free()
	await process_frame
	print("STATIONS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
