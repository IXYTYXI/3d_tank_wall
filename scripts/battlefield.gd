extends Node3D

const Visual = preload("res://scripts/tank_visual.gd")
const Assets = preload("res://scripts/battle_assets.gd")
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
	# Pairs of sloped reinforced road barriers keep the central route open.
	for data in [Vector3(-10,0,24),Vector3(12,0,4),Vector3(-7,0,-19),Vector3(22,0,-32)]:
		for offset in [-1.8,1.8]:
			add_asset("barrier",Vector3(data.x+offset,0,data.z),Vector3.ONE,0,0)
	for side in [-1.0,1.0]:
		for i in range(5):
			add_asset("dragon_tooth",Vector3(side*(18+i*2.7),0,-8 if side<0 else -48),Vector3.ONE,side*0.08,i%3)
		for i in range(3):
			add_asset("hedgehog",Vector3(side*(14+i*4.0),0,30 if side<0 else -18),Vector3.ONE,i*0.31,0)
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
	var rock_spots: Array[Vector2] = []
	for i in range(52):
		var x := rng.randf_range(-105,105)
		var z := rng.randf_range(-110,90)
		if absf(x)<10 or Vector2(x,z-43).length()<15 or Vector2(x,z-65).length()<13:
			continue
		var dimensions := Vector3(rng.randf_range(2.6,6.5),rng.randf_range(1.6,4.2),rng.randf_range(2.8,5.8))
		var body := add_asset("rock",Vector3(x,dimensions.y*0.34,z),dimensions,rng.randf_range(0,TAU),i%7)
		body.set_meta("rock",true)
		rock_spots.append(Vector2(x,z))
	for i in range(112):
		var x := rng.randf_range(-115,115)
		var z := rng.randf_range(-115,110)
		if absf(x)<27:
			continue
		var crowded := false
		for point in rock_spots:
			if point.distance_to(Vector2(x,z))<4:
				crowded = true
		if crowded:
			continue
		var scale_value := rng.randf_range(0.72,1.35)
		add_asset("pine",Vector3(x,0,z),Vector3.ONE*scale_value,rng.randf_range(0,TAU),i%6)
	Assets.ridgeline(self)
	# Invisible boundary walls retain the tank inside the playable terrain.
	for side in [-1.0, 1.0]:
		block(Vector3(2, 30, 242), Vector3(side * 121, 5, 0), concrete, false)
		block(Vector3(242, 30, 2), Vector3(0, 5, side * 121), concrete, false)

func add_asset(kind: String, pos: Vector3, dimensions: Vector3, yaw: float, seed_value: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("asset_kind",kind)
	add_child(body)
	body.position = Vector3(pos.x,height(pos.x,pos.z)+pos.y,pos.z)
	body.rotation.y = yaw
	var model: Node3D = Assets.create(kind,body,seed_value)
	model.scale = dimensions
	if kind == "pine":
		for child in model.get_children():
			if child is GeometryInstance3D:
				child.visibility_range_end = 100
		var distant: Node3D = Assets.pine(body,100+seed_value)
		distant.scale = dimensions
		for child in distant.get_children():
			if child is GeometryInstance3D:
				child.visibility_range_begin = 100
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shape := CollisionShape3D.new()
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.26*dimensions.x
		trunk.height = 6.0*dimensions.y
		shape.shape = trunk
		shape.position.y = trunk.height*0.5
		body.add_child(shape)
	elif kind == "hedgehog":
		for angle in [Vector3(0,0,PI/4),Vector3(0,0,-PI/4),Vector3(PI/2,0,0)]:
			var shape := CollisionShape3D.new()
			var beam := BoxShape3D.new()
			beam.size = Vector3(0.38,3.0,0.4)
			shape.shape = beam
			shape.position.y = 1.12
			shape.rotation = angle
			body.add_child(shape)
	else:
		# Main solid surface only: fittings and paint don't expand the collider.
		var mesh: MeshInstance3D
		for child in model.get_children():
			if child is MeshInstance3D:
				mesh = child
				break
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_convex_shape(true,true)
		shape.scale = dimensions
		body.add_child(shape)
	return body

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
