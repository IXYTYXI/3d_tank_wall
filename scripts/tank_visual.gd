extends Node3D

var turret: Node3D
var barrel: Node3D
var muzzle: Marker3D
var wheels: Array[MeshInstance3D] = []
var armor: StandardMaterial3D
var dark: StandardMaterial3D
var steel: StandardMaterial3D

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = mat
	parent.add_child(item)
	item.position = pos
	return item

static func cylinder(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	item.mesh = mesh
	item.material_override = mat
	parent.add_child(item)
	item.position = pos
	return item

func _ready() -> void:
	armor = material(Color("586350"), 0.55, 0.57)
	dark = material(Color("202928"), 0.4, 0.8)
	steel = material(Color("88917b"), 0.65, 0.48)
	box(self, Vector3(2.7, 0.85, 4.6), Vector3(0, 1.0, 0), armor)
	box(self, Vector3(2.5, 0.22, 3.0), Vector3(0, 1.54, 0.35), armor)
	var front := box(self, Vector3(2.7, 0.18, 1.25), Vector3(0, 1.25, -2.05), steel)
	front.rotation.x = deg_to_rad(24)
	for side in [-1.0, 1.0]:
		box(self, Vector3(0.62, 0.9, 4.7), Vector3(side * 1.55, 0.64, 0), dark)
		box(self, Vector3(0.78, 0.13, 4.9), Vector3(side * 1.55, 1.19, 0), armor)
		for i in range(7):
			var wheel := cylinder(self, 0.40, 0.66, Vector3(side * 1.56, 0.59, -1.91 + i * 0.64), steel)
			wheel.rotation.z = PI / 2
			wheels.append(wheel)
			var hub := cylinder(self, 0.17, 0.69, wheel.position, dark)
			hub.rotation.z = PI / 2
		for i in range(24):
			box(self, Vector3(0.68, 0.08, 0.13), Vector3(side * 1.56, 0.17, -2.23 + i * 0.194), steel)
		for i in range(4):
			box(self, Vector3(0.08, 0.44, 0.96), Vector3(side * 1.94, 1.02, -1.65 + i * 1.08), armor)
		box(self, Vector3(0.24, 0.17, 0.09), Vector3(side * 1.08, 1.34, -2.53), material(Color("e9dcac"), 0.2))
	for i in range(8):
		box(self, Vector3(1.5, 0.04, 0.09), Vector3(0, 1.69, 1.1 + i * 0.1), dark)
	turret = Node3D.new()
	add_child(turret)
	turret.position = Vector3(0, 1.65, -0.25)
	cylinder(turret, 1.03, 0.20, Vector3.ZERO, dark)
	box(turret, Vector3(2.05, 0.66, 2.05), Vector3(0, 0.38, 0.12), armor)
	for side in [-1.0, 1.0]:
		var cheek := box(turret, Vector3(0.36, 0.65, 1.3), Vector3(side * 0.99, 0.35, -0.32), steel)
		cheek.rotation.y = side * deg_to_rad(16)
		for i in range(3):
			box(turret, Vector3(0.22, 0.18, 0.32), Vector3(side * 1.15, 0.65, i * 0.32), dark)
	cylinder(turret, 0.38, 0.12, Vector3(0.45, 0.77, 0.4), steel)
	box(turret, Vector3(0.28, 0.17, 0.4), Vector3(-0.5, 0.81, -0.28), dark)
	cylinder(turret, 0.018, 1.8, Vector3(-0.8, 1.45, 0.88), dark)
	box(turret, Vector3(1.7, 0.45, 0.38), Vector3(0, 0.34, 1.28), dark)
	barrel = Node3D.new()
	turret.add_child(barrel)
	barrel.position = Vector3(0, 0.38, -0.94)
	box(barrel, Vector3(0.68, 0.48, 0.43), Vector3.ZERO, steel)
	var tube := cylinder(barrel, 0.105, 3.6, Vector3(0, 0, -1.75), armor)
	tube.rotation.x = PI / 2
	var sleeve := cylinder(barrel, 0.17, 0.7, Vector3(0, 0, -0.49), dark)
	sleeve.rotation.x = PI / 2
	box(barrel, Vector3(0.26, 0.23, 0.4), Vector3(0, 0, -3.49), dark)
	muzzle = Marker3D.new()
	barrel.add_child(muzzle)
	muzzle.position.z = -3.72

func animate(speed: float, dt: float) -> void:
	for wheel in wheels:
		wheel.rotate_y(speed * dt / 0.4)
