extends SceneTree
const Progression = preload("res://scripts/progression/desk_progression.gd")
const SaveStore = preload("res://scripts/progression/save_store.gd")
var desk: Node3D
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func run() -> void:
	desk = load("res://scenes/desk.tscn").instantiate()
	desk.progression_enabled = false
	root.add_child(desk)
	var progress = Progression.new()
	progress.persistence = false
	desk.progression = progress
	desk.add_child(progress)
	progress.setup(desk)
	desk.set_paused(false)
	var flow = desk.automation
	flow.set_process(false)
	flow.advance(0)
	check(flow.moving != null, "Auto feed reserves a paper on startup")
	var first: Node3D = flow.moving
	check(desk.pick_at(desk.camera.unproject_position(first.position)) != first, "Moving paper is excluded from selection")
	desk.pickup(first, desk.camera.unproject_position(first.position))
	check(desk.held == null, "Moving paper cannot be grabbed")
	var before: Vector3 = first.position
	desk.set_paused(true)
	flow.advance(2.0)
	check(first.position.is_equal_approx(before), "Pause freezes automatic transport")
	desk.set_paused(false)
	flow.advance(10)
	check(first.position.is_equal_approx(Vector3(0, 0.2, 0)) and flow.moving == null, "Paper arrives centered for stamping")
	flow.advance(0)
	check(flow.moving == null, "Occupied center blocks a second feed")
	var stamp: Node3D = desk.items[3]
	desk.pickup(stamp, desk.camera.unproject_position(stamp.position))
	stamp.position = Vector3(0, 0.28, 0)
	check(desk.try_stamp(), "Centered automatic paper can be stamped")
	flow.advance(0)
	check(flow.moving == null, "Paper waits until stamp stroke finishes")
	await create_timer(0.4).timeout
	desk.set_paused(false)
	flow.advance(0)
	check(flow.moving == first, "Stamped sheet automatically leaves work area")
	check(not desk.try_stamp(), "Cannot stamp paper while it is travelling")
	var snapshot: Dictionary = progress.snapshot()
	var in_flight: Dictionary = snapshot.papers.filter(func(p): return p.serial == first.serial)[0]
	check(is_equal_approx(in_flight.position[0], 3.55), "Save resolves in-flight paper to reserved destination")
	flow.advance(10)
	check(desk.delivery_count == 1 and first.position.x > 3, "Automatic output enters sale zone")
	flow.advance(0)
	check(flow.moving != null and flow.moving != first, "Next paper feeds while stamp remains held")
	var old_duration: float = flow.duration
	flow.cancel()
	progress.economy.balance = 300
	check(progress.economy.buy(&"paper_transport", 0), "Transport speed upgrade can be bought")
	flow.begin_move(desk.items[1], Vector3.ZERO)
	check(is_equal_approx(flow.speed(), 3.5) and flow.duration < old_duration, "Speed upgrade increases movement by forty percent")
	flow.advance(0.3)
	desk.reset_desk()
	check(flow.moving == null and desk.items.size() == 4, "Reset cancels transfer without stale paper references")
	# A resting stamp in the center must not be covered by automatic paper.
	stamp = desk.items[3]
	stamp.position = Vector3(0, 0.09, 0)
	flow.advance(0)
	check(flow.moving == null, "Resting stamp blocks automatic feed into its space")
	stamp.position = Vector3(1.53, 0.15, -1.16)
	var office = desk.office
	check(office.at_desk and desk.camera.current, "Start in fixed desk view")
	desk.pickup(stamp, desk.camera.unproject_position(stamp.position))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	root.push_input(key, true)
	check(not office.at_desk and desk.held == null and office.eye.current, "E stands up and safely puts held object down")
	await physics_frame
	await physics_frame
	var starting_z: float = office.player.position.z
	Input.action_press("office_forward")
	for frame in range(100):
		await physics_frame
	Input.action_release("office_forward")
	check(office.player.position.z < starting_z and office.player.position.z > 2.9, "W moves player and desk collision prevents crossing tabletop")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(30, -10)
	root.push_input(mouse, true)
	check(absf(office.player.rotation.y) > 0.01, "Mouse turns first-person view")
	desk.set_paused(true)
	var paused_position: Vector3 = office.player.position
	Input.action_press("office_right")
	await create_timer(0.12).timeout
	Input.action_release("office_right")
	check(office.player.position.is_equal_approx(paused_position) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Walking pause freezes player and releases mouse")
	desk.set_paused(false)
	office.player.position = Vector3(0, -1.04, 3.7)
	office.interact()
	check(office.at_desk and desk.camera.current and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "E at workstation restores fixed camera and cursor")
	# Make a full output batch; verify cargo, envelopes and paid quantity conservation.
	for item in desk.items:
		if item.kind == "paper":
			item.position = Vector3(3.55, item.position.y, 0)
			item.add_impression(item.global_position)
	desk.update_delivery()
	office.leave_desk()
	office.player.position = Vector3(3.55, -1.04, 3.7)
	office.interact()
	check(progress.office_state.cargo == 3 and desk.delivery_count == 0 and desk.items.size() == 4, "Collecting three sheets transfers them to hands and replenishes desk")
	check(not office.take_output() and progress.office_state.cargo == 3, "Capacity blocks a second pickup")
	check(office.sell_cargo() and progress.office_state.cargo == 0, "Cargo sale service resolves a single transaction")
	# Reload a carried batch for the station workflow, isolated from production saves.
	progress.office_state = {"cargo": 3, "enveloped": false}
	var test_dir := "res://tests/.tmp/office-" + str(Time.get_ticks_usec())
	progress.store.path = test_dir + "/save.json"
	progress.persistence = true
	check(progress.persist(), "Carried batch persists")
	var data: Dictionary = progress.store.load_game()
	check(data.office.cargo == 3 and not data.office.enveloped, "Cargo survives save/load without converting early")
	office.player.position = Vector3(6.4, -1.04, -4)
	office.interact()
	check(office.job_remaining > 0, "E starts envelope station operation")
	desk.set_paused(true)
	var remaining: float = office.job_remaining
	await create_timer(0.12).timeout
	check(office.job_remaining == remaining, "Pause freezes envelope operation")
	desk.set_paused(false)
	await create_timer(1.7).timeout
	check(progress.office_state.cargo == 3 and progress.office_state.enveloped, "Enveloping conserves quantity and changes process state")
	check(not office.start_envelopes(), "Envelope process cannot be applied twice")
	var balance_before: int = progress.economy.balance
	office.player.position = Vector3(-6.4, -1.04, -4)
	office.interact()
	check(progress.office_state.cargo == 0 and progress.economy.balance == balance_before + 600, "Expedition pays double for three envelopes and consumes cargo")
	check(not office.sell_cargo() and progress.economy.balance == balance_before + 600, "Repeated expedition action cannot pay twice")
	progress.office_state = {"cargo": 1, "enveloped": true}
	progress.store.path = test_dir
	check(not office.sell_cargo() and progress.office_state.cargo == 1 and progress.economy.balance == balance_before + 600, "Failed save rolls back cargo sale")
	progress.store.path = test_dir + "/legacy.json"
	var legacy: Dictionary = progress.snapshot()
	legacy.version = 1
	legacy.erase("office")
	check(progress.store.save(legacy), "Version one fixture is valid")
	var migrated: Dictionary = progress.store.load_game()
	check(migrated.version == 2 and migrated.office.cargo == 0 and migrated.economy.balance == legacy.economy.balance and migrated.economy.levels.has("paper_transport"), "Legacy save migrates while preserving money and upgrades")
	for iteration in range(8):
		office.sit_down()
		office.leave_desk()
	check(not office.at_desk and office.eye.current and desk.items.size() == 4, "Repeated mode transitions preserve objects and active camera")
	office.sit_down()
	progress.persistence = false
	progress.office_state = {"cargo": 0, "enveloped": false}
	desk.reset_desk()
	flow.advance(0)
	flow.advance(10)
	stamp = desk.items[3]
	desk.pickup(stamp, desk.camera.unproject_position(stamp.position))
	stamp.position = Vector3(0, 0.28, 0)
	for paper_index in range(3):
		check(desk.try_stamp(), "Continuous automatic batch accepts stamp %d" % (paper_index + 1))
		await create_timer(0.35).timeout
		flow.advance(0)
		flow.advance(10)
		flow.advance(0)
		flow.advance(10)
	check(desk.delivery_count == 3, "Three automatic papers arrive in output without re-grabbing stamp")
	desk.drop_item()
	var batch_balance: int = progress.economy.balance
	progress.collect()
	check(progress.economy.balance == batch_balance + 300 and desk.items.size() == 4, "Automatic batch pays once and creates fresh supply")
	flow.advance(0)
	check(flow.moving != null, "Automatic feeding resumes after whole batch sale")
	print("OFFICE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
