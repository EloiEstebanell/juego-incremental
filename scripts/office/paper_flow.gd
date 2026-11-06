extends Node
## Only one document moves at a time. Reservations exclude moving objects from input.
var desk: Node3D
var moving: Node3D
var origin := Vector3.ZERO
var destination := Vector3.ZERO
var elapsed := 0.0
var duration := 1.4
var enabled := true

func setup(owner_desk: Node3D) -> void:
	desk = owner_desk

func cancel() -> void:
	moving = null
	elapsed = 0.0

func speed() -> float:
	return desk.progression.economy.value(3, 2.5) if desk.progression else 2.5

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not enabled or desk == null or desk.paused or desk.busy:
		return
	if is_instance_valid(moving):
		elapsed += delta
		var weight := clampf(elapsed / duration, 0, 1)
		moving.position = origin.lerp(destination, smoothstep(0, 1, weight))
		if weight >= 1:
			moving.position = destination
			moving = null
			desk.update_delivery()
			if desk.progression:
				desk.progression.persist()
		return
	moving = null
	if desk.held and desk.held.kind == "paper":
		return
	# Finished sheets leave before a new sheet enters the work area.
	var output_count := 0
	for item in desk.items:
		if item.kind == "paper" and in_output(item):
			output_count += 1
	for item in desk.items:
		if item.kind == "paper" and not item.impressions.is_empty() and not in_output(item):
			if output_count < (desk.stations.capacity("stamp_out") if desk.stations else 3):
				begin_move(item, Vector3(3.55, 0.09 + mini(output_count, 24) * 0.025, 0))
			return
	for item in desk.items:
		if item == desk.held:
			continue
		if absf(item.position.x) < 1.4 and absf(item.position.z) < 1.2:
			return
	var candidate: Node3D
	for item in desk.items:
		if item.kind == "paper" and item.impressions.is_empty():
			if candidate == null or item.position.y > candidate.position.y:
				candidate = item
	if candidate:
		begin_move(candidate, Vector3(0, 0.20, 0))

func begin_move(item: Node3D, target: Vector3) -> void:
	moving = item
	origin = item.position
	destination = target
	elapsed = 0.0
	duration = maxf(0.12, origin.distance_to(target) / speed())
	if desk.hovered == item:
		item.set_highlight(false)
		desk.hovered = null
	if desk.progression:
		desk.progression.persist()

func in_output(item: Node3D) -> bool:
	return item.position.x - item.half_size.x >= desk.OUTPUT_X and absf(item.position.z) + item.half_size.y <= 1.83
