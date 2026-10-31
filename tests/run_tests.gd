extends SceneTree
var desk: Node3D
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func run() -> void:
	desk = load("res://scenes/desk.tscn").instantiate()
	desk.progression_enabled = false
	desk.automation_enabled = false
	desk.office_enabled = false
	root.add_child(desk)
	await process_frame
	await process_frame
	desk.set_paused(false)
	check(desk.items.size() == 4, "Three documents and one stamp")
	var paper: Node3D = desk.items[2]
	var stamp: Node3D = desk.items[3]
	var screen: Vector2 = desk.camera.unproject_position(paper.global_position + Vector3(0, 0.023, 0))
	check(desk.pick_at(screen) == paper, "Top visible sheet wins overlap selection")
	var corner: Vector2 = desk.camera.unproject_position(paper.global_position + Vector3(0.45, 0.023, 0.6))
	var center_before: Vector2 = desk.camera.unproject_position(paper.global_position)
	desk.pickup(paper, corner)
	var center_after: Vector2 = desk.camera.unproject_position(paper.global_position)
	check(center_after.distance_to(center_before) < 0.1, "Pickup preserves screen position")
	desk.move_held(corner + Vector2(120, 40))
	check(desk.camera.unproject_position(paper.global_position).distance_to(center_after + Vector2(120, 40)) < 0.5, "Corner grab preserves cursor offset")
	desk.pickup(stamp, screen)
	check(desk.held == paper and not stamp.held, "Cannot hold two objects")
	desk.move_held(Vector2(-10000, 10000))
	check(absf(paper.position.x) + paper.half_size.x <= desk.TABLE_HALF.x + 0.001 and absf(paper.position.z) + paper.half_size.y <= desk.TABLE_HALF.y + 0.001, "Extreme mouse motion keeps whole object recoverable")
	desk.drop_item()
	check(desk.held == null, "Drop clears held state")
	desk.reset_desk()
	paper = desk.items[2]
	stamp = desk.items[3]
	paper.position = Vector3(0, 0.16, 0)
	desk.pickup(stamp, desk.camera.unproject_position(stamp.global_position))
	stamp.position = Vector3(0, 0.28, 0)
	check(desk.stamp_target() == paper, "Stamp resolves document inside footprint")
	stamp.position.x = 0.60
	check(desk.stamp_target() == null, "Stamp crossing document edge is rejected")
	stamp.position.x = 2.0
	check(not desk.try_stamp(), "Empty desk rejects stamping")
	stamp.position.x = 0.0
	check(desk.try_stamp(), "Valid stamp starts animation")
	check(not desk.try_stamp(), "Rapid click cannot duplicate an active stroke")
	desk.drop_item()
	check(desk.held == stamp, "Dropping during stroke is safely blocked")
	desk.set_paused(true)
	await create_timer(0.18).timeout
	check(paper.impressions.is_empty() and desk.busy, "Pause freezes before contact")
	desk.set_paused(false)
	await create_timer(0.4).timeout
	check(paper.impressions.size() == 1 and not desk.busy, "Resume completes exactly one impression")
	var local_mark: Vector3 = paper.ink_root.get_child(0).position
	paper.position += Vector3(0.3, 0, 0.2)
	check(paper.ink_root.get_child(0).position.is_equal_approx(local_mark), "Ink stays attached in paper local coordinates")
	desk.drop_item()
	paper.position = Vector3(3.55, 0.16, 0)
	desk.update_delivery()
	check(desk.delivery_count == 1, "Stamped paper in output counts once")
	for index in range(5):
		desk.update_delivery()
	check(desk.delivery_count == 1, "Repeated recount does not accumulate deliveries")
	desk.pickup(paper, desk.camera.unproject_position(paper.global_position))
	check(desk.delivery_count == 0, "Removing output document decrements count")
	desk.drop_item()
	for index in range(40):
		paper.add_impression(paper.global_position)
	check(paper.impressions.size() == 24 and paper.ink_root.get_child_count() == 24, "Repeated stamping has bounded visuals and state")
	desk.reset_desk()
	stamp = desk.items[3]
	paper = desk.items[2]
	paper.position = Vector3(0, 0.16, 0)
	desk.items[1].position = Vector3(0, 0.12, 0)
	desk.pickup(stamp, desk.camera.unproject_position(stamp.global_position))
	stamp.position = Vector3(0, 0.28, 0)
	check(desk.stamp_target() == paper, "Stamp cannot mark hidden lower sheet")
	paper.position.x = 0.8
	check(desk.stamp_target() == null, "Partial upper sheet blocks stamping through its corner")
	paper.position.x = 0.0
	desk.try_stamp()
	desk.reset_desk()
	await create_timer(0.4).timeout
	check(not desk.busy and desk.held == null and desk.delivery_count == 0 and desk.items[2].impressions.is_empty(), "Reset mid-stroke cancels callbacks and clears all state")
	# Exercise real input routing, including a button consuming its mouse click.
	paper = desk.items[2]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = desk.camera.unproject_position(paper.global_position + Vector3(0, 0.023, 0))
	root.push_input(click, true)
	await process_frame
	check(desk.held == paper, "Viewport mouse click reaches object interaction")
	# UI buttons consume clicks; pausing must not drop the currently held paper.
	var pause_button: Button = desk.ui.get_child(2).get_child(0).get_child(2)
	var ui_release := InputEventMouseButton.new()
	ui_release.button_index = MOUSE_BUTTON_LEFT
	ui_release.pressed = false
	ui_release.position = click.position
	root.push_input(ui_release, true)
	var ui_click := InputEventMouseButton.new()
	ui_click.button_index = MOUSE_BUTTON_LEFT
	ui_click.pressed = true
	ui_click.position = pause_button.get_global_rect().get_center()
	root.push_input(ui_click, true)
	ui_release.position = ui_click.position
	root.push_input(ui_release, true)
	await process_frame
	check(desk.paused and desk.held == paper, "Pause button consumes click without dropping held paper")
	desk.set_paused(false)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	desk.reset_desk()
	# Ten complete cycles verify no stale interaction or stamp state leaks.
	for cycle in range(10):
		paper = desk.items[2]
		stamp = desk.items[3]
		desk.pickup(paper, desk.camera.unproject_position(paper.global_position))
		paper.position.x = 0
		paper.position.z = 0
		desk.drop_item()
		desk.pickup(stamp, desk.camera.unproject_position(stamp.global_position))
		stamp.position = Vector3(0, 0.28, 0)
		desk.try_stamp()
		await create_timer(0.32).timeout
		desk.drop_item()
		desk.pickup(paper, desk.camera.unproject_position(paper.global_position))
		paper.position.x = 3.55
		desk.drop_item()
		check(desk.delivery_count == 1, "Complete manual cycle %d" % (cycle + 1))
		desk.reset_desk()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
