extends Node3D
## The shared object has no knowledge of input, camera or economy.
const Geo = preload("res://scripts/geometry.gd")
var kind: String = "paper"
var serial: int = 1
var half_size := Vector2(0.68, 0.88)
var hit_height: float = 0.025
var base_mesh: MeshInstance3D
var base_color := Color("eee9d8")
var held := false
var hovered := false
var impressions: Array[Vector2] = []
var ink_root: Node3D
const INK_LIMIT := 24

func build(type: String, number: int) -> void:
	kind = type
	serial = number
	if kind == "stamp":
		half_size = Vector2(0.30, 0.24)
		hit_height = 0.73
		base_color = Color("283e3d")
		base_mesh = Geo.box(self, Vector3(0.60, 0.13, 0.48), Vector3(0, 0.065, 0), base_color)
		Geo.box(self, Vector3(0.53, 0.035, 0.42), Vector3(0, 0.015, 0), Color("9c5141"))
		Geo.cylinder(self, 0.075, 0.29, Vector3(0, 0.27, 0), Color("a4aaa2"))
		Geo.cylinder(self, 0.19, 0.25, Vector3(0, 0.53, 0), Color("9a4836"))
		Geo.cylinder(self, 0.21, 0.06, Vector3(0, 0.68, 0), Color("b06145"))
		Geo.label(self, "AP", Vector3(0, 0.714, 0), 28, Color("f1dbaf"))
	else:
		base_mesh = Geo.box(self, Vector3(1.36, 0.022, 1.76), Vector3(0, 0.011, 0), base_color)
		Geo.box(self, Vector3(0.09, 0.003, 0.18), Vector3(-0.48, 0.025, -0.59), Color("a4543e"))
		Geo.label(self, "OFICINA CENTRAL", Vector3(0.1, 0.027, -0.62), 22, Color("354a49"), 0.0038)
		Geo.label(self, "SOLICITUD  /  %03d" % serial, Vector3(0, 0.028, -0.35), 27, Color("354a49"), 0.0038)
		for index in range(5):
			Geo.box(self, Vector3(0.99 if index != 4 else 0.62, 0.002, 0.016), Vector3(-0.05, 0.026, -0.13 + index * 0.12), Color("69796c"))
		Geo.label(self, "PENDIENTE DE TRAMITAR", Vector3(0, 0.028, 0.64), 16, Color("586b5f"), 0.0032)
	ink_root = Node3D.new()
	add_child(ink_root)

func set_highlight(value: bool) -> void:
	hovered = value
	var mat := base_mesh.material_override as StandardMaterial3D
	mat.albedo_color = base_color.lerp(Color("f7cf7a"), 0.28 if value or held else 0.0)

func ray_distance(origin: Vector3, direction: Vector3) -> float:
	var local_origin := to_local(origin)
	var local_direction := global_basis.inverse() * direction
	var bounds := AABB(Vector3(-half_size.x, 0, -half_size.y), Vector3(half_size.x * 2, hit_height, half_size.y * 2))
	var point: Variant = bounds.intersects_ray(local_origin, local_direction)
	if point == null:
		return INF
	return origin.distance_to(to_global(point))

func contains_footprint(world_point: Vector3, margin: Vector2 = Vector2.ZERO) -> bool:
	var local := to_local(world_point)
	return absf(local.x) <= half_size.x - margin.x and absf(local.z) <= half_size.y - margin.y

func add_impression(world_point: Vector3) -> void:
	var local := to_local(world_point)
	impressions.append(Vector2(local.x, local.z))
	if impressions.size() > INK_LIMIT:
		impressions.pop_front()
		var oldest := ink_root.get_child(0)
		ink_root.remove_child(oldest)
		oldest.queue_free()
	var mark := Node3D.new()
	ink_root.add_child(mark)
	mark.position = Vector3(local.x, 0.031 + impressions.size() * 0.00015, local.z)
	var ink := Color("a14b38")
	for edge in [-1, 1]:
		Geo.box(mark, Vector3(0.50, 0.001, 0.012), Vector3(0, 0, edge * 0.16), ink)
		Geo.box(mark, Vector3(0.012, 0.001, 0.32), Vector3(edge * 0.25, 0, 0), ink)
	Geo.label(mark, "APROBADO", Vector3(0, 0.002, 0), 20, ink, 0.004)



