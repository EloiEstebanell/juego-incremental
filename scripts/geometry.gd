extends RefCounted
## Small shared geometry factory. All prototype art is generated locally.

static func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.78
	result.metallic = metallic
	return result

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node

static func label(parent: Node3D, value: String, pos: Vector3, size: int, color: Color, scale_value: float = 0.004) -> Label3D:
	var node := Label3D.new()
	node.text = value
	node.font_size = size
	node.pixel_size = scale_value
	node.modulate = color
	node.outline_size = 0
	node.no_depth_test = false
	node.shaded = false
	node.rotation_degrees.x = -90
	parent.add_child(node)
	node.position = pos
	return node


