extends Node3D

const Visual = preload("res://scripts/tank_visual.gd")
var targets: Array[StaticBody3D] = []
var terrain: StaticBody3D
var rng := RandomNumberGenerator.new()

static func height(x: float, z: float) -> float:
	return 2.5 * sin(x * 0.035) * cos(z * 0.032) + 1.5 * sin(z * 0.057) + 3.0 * exp(-pow((x + 28) / 20, 2) - pow((z + 5) / 25, 2))

func _ready() -> void:
	rng.seed = 73291
	build_terrain()
	var concrete := Visual.material(Color("777867"))
	var rust := Visual.material(Color("725347"), 0.35)
	for data in [Vector3(-10, 0, 24), Vector3(12, 0, 4), Vector3(-7, 0, -19), Vector3(22, 0, -32)]:
		var pos: Vector3 = Vector3(data.x, height(data.x, data.z), data.z)
		block(Vector3(7, 2.8, 2.2), pos + Vector3(0, 1.4, 0), concrete)
		for offset in [-2.6, 0.0, 2.6]:
			Visual.box(self, Vector3(0.12, 0.16, 2.26), pos + Vector3(offset, 2.55, 0), rust)
	for i in range(6):
		var x: float = [-19.0, 0.0, 20.0, -31.0, 33.0, 4.0][i]
		var z: float = [-14.0, -31.0, -46.0, -58.0, -71.0, -90.0][i]
		var target := block(Vector3(3, 2.3, 0.55), Vector3(x, height(x, z) + 2.2, z), rust)
		target.set_meta("target", true)
		target.set_meta("hp", 2)
		target.set_meta("index", i + 1)
		targets.append(target)
		var face := Visual.box(target, Vector3(1.65, 1.65, 0.05), Vector3(0, 0, 0.3), Visual.material(Color("d3b98a")))
		Visual.box(face, Vector3(0.45, 0.45, 0.04), Vector3(0, 0, 0.04), rust)
		Visual.box(target, Vector3(0.14, 2.5, 0.14), Vector3(-1, -1.5, 0), concrete)
		Visual.box(target, Vector3(0.14, 2.5, 0.14), Vector3(1, -1.5, 0), concrete)
	for i in range(65):
		var x := rng.randf_range(-105, 105)
		var z := rng.randf_range(-110, 90)
		if absf(x) < 8 or Vector2(x, z - 43).length() < 15:
			continue
		var size := Vector3(rng.randf_range(2, 6), rng.randf_range(1, 4), rng.randf_range(2, 5))
		var rock := block(size, Vector3(x, height(x, z) + size.y * 0.3, z), Visual.material(Color("646957")))
		rock.rotation.y = rng.randf_range(0, TAU)
		rock.rotation.z = rng.randf_range(-0.18, 0.18)
	for i in range(100):
		var x := rng.randf_range(-115, 115)
		var z := rng.randf_range(-115, 110)
		if absf(x) < 26:
			continue
		var base := Vector3(x, height(x, z), z)
		var trunk := Visual.cylinder(self, 0.16, 5, base + Vector3(0, 2.5, 0), Visual.material(Color("454b3b")))
		trunk.rotation.z = rng.randf_range(-0.13, 0.13)
		for j in range(3):
			var crown := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0
			cone.bottom_radius = 1.7 - j * 0.35
			cone.height = 2.7
			cone.radial_segments = 7
			crown.mesh = cone
			crown.material_override = Visual.material(Color("344638"))
			add_child(crown)
			crown.position = base + Vector3(0, 3.6 + j, 0)
	for i in range(18):
		var angle := TAU * i / 18
		var mountain := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 3
		cone.bottom_radius = rng.randf_range(40, 65)
		cone.height = rng.randf_range(35, 65)
		cone.radial_segments = 7
		mountain.mesh = cone
		mountain.material_override = Visual.material(Color("616d65"))
		add_child(mountain)
		mountain.position = Vector3(sin(angle) * 180, 5, cos(angle) * 180)
	# Invisible boundary walls retain the tank inside the playable terrain.
	for side in [-1.0, 1.0]:
		block(Vector3(2, 30, 242), Vector3(side * 121, 5, 0), concrete, false)
		block(Vector3(242, 30, 2), Vector3(0, 5, side * 121), concrete, false)

func block(size: Vector3, pos: Vector3, mat: Material, visible_mesh: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visible_mesh:
		Visual.box(body, size, Vector3.ZERO, mat)
	return body

func build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-120, 120, 3):
		for x in range(-120, 120, 3):
			var a := Vector3(x, height(x, z), z)
			var b := Vector3(x + 3, height(x + 3, z), z)
			var c := Vector3(x, height(x, z + 3), z + 3)
			var d := Vector3(x + 3, height(x + 3, z + 3), z + 3)
			for p in [a, b, c, b, d, c]:
				var noise := rng.randf_range(-0.018, 0.018)
				var path := exp(-pow((p.x - 4 * sin(p.z * 0.04)) / 6, 2))
				var color := Color("737753").lerp(Color("9b8b65"), path * 0.65)
				st.set_color(color.lightened(noise + p.y * 0.009))
				st.add_vertex(p)
	st.generate_normals()
	var mesh := st.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	visual.material_override = mat
	add_child(visual)
	terrain = StaticBody3D.new()
	terrain.collision_layer = 1
	add_child(terrain)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	terrain.add_child(collision)
