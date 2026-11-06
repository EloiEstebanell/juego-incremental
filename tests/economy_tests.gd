extends SceneTree
const Economy = preload("res://scripts/progression/economy.gd")
const SaveStore = preload("res://scripts/progression/save_store.gd")
const Progression = preload("res://scripts/progression/desk_progression.gd")
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
func write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func run() -> void:
	var economy = Economy.new()
	check(economy.catalog.validate().is_empty(), "Catalog validates")
	check(economy.payout() == 100, "Initial payment is exactly one cent")
	check(not economy.buy(&"paper_quality", 0), "Insufficient funds cannot buy")
	economy.balance = 300
	check(economy.buy(&"paper_quality", 0) and economy.balance == 0 and economy.payout() == 200, "Exact funds buy additive improvement")
	economy.balance = 100000
	check(not economy.buy(&"paper_quality", 0), "Stale purchase cannot charge twice")
	check(economy.buy(&"official_stamp", 0) and economy.payout() == 300, "Additive base precedes multiplicative stamp")
	economy.levels["official_stamp"] = 3
	check(economy.payout() == 675 and Economy.money(675) == "0.0675 €", "Fractional cents are kept as integers and displayed")
	economy.levels["paper_quality"] = 5
	check(not economy.buy(&"paper_quality", 5), "Maximum level enforced")
	economy.levels.clear()
	check(not economy.buy(&"official_stamp", 0), "Prerequisite enforced")
	economy.levels["light_handle"] = 4
	check(is_equal_approx(economy.value(2, 0.27), 0.27 * pow(0.8, 4)), "Speed effect compounds and remains positive")
	var clone: UpgradeCatalog = economy.catalog.duplicate(true)
	var duplicate: UpgradeDefinition = clone.upgrades[0].duplicate(true)
	duplicate.id = &"test_paper"
	duplicate.initial_cost = 1
	clone.upgrades.append(duplicate)
	economy.catalog = clone
	check(clone.validate().is_empty() and economy.buy(&"test_paper", 0) and economy.payout() == 200, "New catalog resource works without ID-specific code")
	duplicate.id = &"paper_quality"
	check(not clone.validate().is_empty(), "Duplicate IDs rejected")
	duplicate.id = &"test_paper"
	duplicate.prerequisite = &"missing"
	check(not clone.validate().is_empty(), "Missing prerequisite rejected")
	duplicate.prerequisite = &"test_paper"
	check(not clone.validate().is_empty(), "Cyclic prerequisite rejected")
	var desk = load("res://scenes/desk.tscn").instantiate()
	desk.stations_enabled = false
	desk.progression_enabled = false
	desk.automation_enabled = false
	desk.office_enabled = false
	root.add_child(desk)
	await process_frame
	desk.set_paused(false)
	var progress = Progression.new()
	progress.persistence = false
	desk.progression = progress
	desk.add_child(progress)
	progress.setup(desk)
	var test_dir := "res://tests/.tmp/" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(test_dir)
	progress.store.path = test_dir + "/save.json"
	progress.persistence = true
	check(progress.store.load_game().is_empty() and progress.store.writable, "No save starts clean")
	var paper = desk.items[2]
	paper.position = Vector3(3.55, 0.16, 0)
	paper.add_impression(paper.global_position)
	desk.update_delivery()
	progress.collect()
	check(progress.economy.balance == 100 and progress.economy.sold == 1 and desk.items.size() == 3, "Sale removes a document and credits once")
	progress.collect()
	check(progress.economy.balance == 100, "Repeated collect cannot sell twice")
	var saved: Dictionary = progress.store.load_game()
	check(saved.economy.balance == 100 and saved.papers.size() == 2, "Sale and removal saved together")
	progress.economy.balance = 300
	progress.purchase(&"paper_quality", 0)
	check(progress.economy.balance == 0 and progress.economy.payout() == 200, "Shop purchase integrated with save")
	progress.purchase(&"paper_quality", 1)
	check(progress.economy.level(&"paper_quality") == 1, "Rapid shop repeat is blocked")
	await process_frame
	var loaded = Economy.new()
	loaded.restore(progress.store.load_game().economy)
	loaded.restore(progress.store.load_game().economy)
	check(loaded.payout() == 200 and Economy.DEFAULT_CATALOG.upgrades[0].effects[0].amount == 100, "Repeated loading neither duplicates effects nor mutates resources")
	var original_snapshot: Dictionary = progress.snapshot()
	var second = SaveStore.new()
	second.path = progress.store.path
	var roundtrip: Dictionary = second.load_game()
	var restored_economy = Economy.new()
	restored_economy.restore(roundtrip.economy)
	check(restored_economy.balance == progress.economy.balance and restored_economy.payout() == progress.economy.payout() and roundtrip.papers.size() == original_snapshot.papers.size() and is_equal_approx(roundtrip.papers[0].position[0], original_snapshot.papers[0].position[0]), "Full snapshot round trip")
	var restored_desk = load("res://scenes/desk.tscn").instantiate()
	restored_desk.stations_enabled = false
	restored_desk.progression_enabled = false
	restored_desk.automation_enabled = false
	restored_desk.office_enabled = false
	root.add_child(restored_desk)
	var restored_progress = Progression.new()
	restored_progress.store.path = second.path
	restored_desk.progression = restored_progress
	restored_desk.add_child(restored_progress)
	restored_progress.setup(restored_desk)
	check(restored_progress.economy.payout() == 200 and restored_desk.items.size() == 3 and restored_progress.next_serial == progress.next_serial, "Scene startup restores progress and remaining documents")
	restored_desk.queue_free()
	await process_frame
	duplicate.id = &"test_paper"
	duplicate.prerequisite = &""
	duplicate.prerequisite_level = 0
	var resource_path := test_dir + "/extra_upgrade.tres"
	var saved_resource := ResourceSaver.save(duplicate, resource_path)
	var from_file = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var custom_catalog: UpgradeCatalog = Economy.DEFAULT_CATALOG.duplicate(true)
	custom_catalog.upgrades.append(from_file)
	var custom_economy = Economy.new()
	custom_economy.catalog = custom_catalog
	custom_economy.balance = 1
	check(saved_resource == OK and custom_catalog.validate().is_empty() and custom_economy.buy(&"test_paper", 0) and custom_economy.payout() == 200, "Serialized extra tres appears in catalog and can be purchased")
	var corrupt := FileAccess.open(second.path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(not second.load_game().is_empty() and second.writable and not second.notice.is_empty(), "Broken primary recovers valid backup with notice")
	check(second.save(original_snapshot), "Recovered backup can be saved safely")
	write_json(second.path, {"version": 999})
	check(second.load_game().is_empty() and not second.writable and not second.save(original_snapshot), "Newer schema is preserved and never overwritten")
	var invalid: Dictionary = original_snapshot.duplicate(true)
	invalid.economy.levels["removed_upgrade"] = 1
	write_json(second.path, invalid)
	check(second.load_game().is_empty() and not second.writable, "Unknown upgrade ID blocks silent loss")
	invalid = original_snapshot.duplicate(true)
	invalid.economy.balance = -1
	check(not second.valid(invalid), "Negative balance rejected")
	invalid = original_snapshot.duplicate(true)
	invalid.papers[0].marks = [["bad", 0]]
	check(not second.valid(invalid), "Invalid document state rejected")
	progress.store.writable = false
	paper = desk.items[0]
	if paper.kind == "stamp":
		paper = desk.items[1]
	paper.position = Vector3(3.55, 0.16, 0)
	paper.add_impression(paper.global_position)
	desk.update_delivery()
	var before: int = progress.economy.balance
	progress.collect()
	check(progress.economy.balance == before and desk.items.has(paper), "Blocked save never consumes documents")
	progress.store.writable = true
	progress.store.path = test_dir # A directory cannot be replaced by a JSON file.
	progress.collect()
	check(progress.economy.balance == before and desk.items.has(paper), "Write failure rolls back sale and paper removal")
	progress.store.path = test_dir + "/final.json"
	desk.reset_desk()
	check(progress.economy.level(&"paper_quality") == 1 and desk.items.size() == 4, "Tidying preserves upgrades and replenishes documents")
	for item in desk.items:
		if item.kind == "paper":
			item.position = Vector3(3.55, item.position.y, 0)
			item.add_impression(item.global_position)
	desk.update_delivery()
	progress.collect()
	check(progress.economy.balance == before + 600 and desk.items.size() == 4 and desk.delivery_count == 0, "Selling a whole batch automatically supplies a new batch")
	var final_data: Dictionary = progress.store.load_game()
	check(final_data.papers.size() == 3 and final_data.economy.balance == progress.economy.balance, "New batch and balance persist")
	progress.open_shop()
	check(desk.paused and progress.overlay.visible and progress.cards.get_child_count() == progress.economy.catalog.upgrades.size(), "Shop pauses desk and displays catalog")
	await process_frame
	await process_frame
	progress.last_purchase_msec = -1000
	var buy_button: Button = progress.cards.get_child(0).get_child(0).get_child(1)
	var button_click := InputEventMouseButton.new()
	button_click.button_index = MOUSE_BUTTON_LEFT
	button_click.position = buy_button.get_global_rect().get_center()
	button_click.pressed = true
	root.push_input(button_click, true)
	button_click = button_click.duplicate()
	button_click.pressed = false
	root.push_input(button_click, true)
	await process_frame
	check(progress.economy.level(&"paper_quality") == 2 and progress.economy.balance == 60, "Real shop button buys quoted next level once")
	progress.confirm.popup_centered()
	check(progress.confirm.visible and progress.economy.balance == 60, "New game confirmation does not reset before acceptance")
	progress.confirm.hide()
	progress.new_game()
	check(progress.economy.balance == 0 and progress.economy.levels.is_empty() and desk.items.size() == 4 and progress.store.load_game().economy.balance == 0, "Confirmed new game resets and persists clean state")
	progress.close_shop()
	check(not desk.paused and not progress.overlay.visible, "Closing shop restores desk")
	print("ECONOMY RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
