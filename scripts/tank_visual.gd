extends Node3D

const Geometry = preload("res://scripts/armor_geometry.gd")
const PaintShader = preload("res://shaders/painted_armor.gdshader")
var turret: Node3D
var barrel: Node3D
var muzzle: Marker3D
var gun_slide: Node3D
var wheels: Array[MeshInstance3D] = []
var armor: ShaderMaterial
var dark: StandardMaterial3D
var steel: StandardMaterial3D
var trim: ShaderMaterial
var track_batches: Array[MultiMesh] = []
var track_phases: Array[float] = [0.0, 0.0]
var recoil := 0.0
const TRACK_LINKS := 54
const TRACK_HALF_LENGTH := 1.85
const TRACK_RADIUS := 0.47
const TRACK_LENGTH := 4 * TRACK_HALF_LENGTH + TAU * TRACK_RADIUS

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
	mesh.radial_segments = 24
	item.mesh = mesh
	item.material_override = mat
	parent.add_child(item)
	item.position = pos
	return item

func paint(color: Color, camo: float = 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PaintShader
	mat.set_shader_parameter("paint_color", color)
	mat.set_shader_parameter("patch_color", Color("2b332d"))
	mat.set_shader_parameter("camouflage", camo)
	return mat

func _ready() -> void:
	armor = paint(Color("60684b"))
	trim = paint(Color("768060"), 0.35)
	dark = material(Color("171d1c"), 0.12, 0.92)
	steel = material(Color("555b56"), 0.78, 0.4)
	build_hull()
	build_tracks()
	build_turret()
	animate(0, 0)

func build_hull() -> void:
	Geometry.plate(self, Vector3(2.85, 0.68, 4.65), Vector3(0, 0.83, 0), armor, 0.1, 0.14)
	Geometry.plate(self, Vector3(2.8, 0.42, 4.35), Vector3(0, 1.30, 0.05), armor, 0.07, 0.17)
	var glacis := Geometry.plate(self, Vector3(2.7, 0.17, 1.23), Vector3(0, 1.18, -1.91), trim)
	glacis.rotation.x = deg_to_rad(29)
	for row in range(2):
		for col in range(4):
			var tile := Geometry.plate(glacis, Vector3(0.59, 0.12, 0.47), Vector3((col - 1.5) * 0.65, 0.13, (row - 0.5) * 0.55), armor, 0.025)
			Geometry.rivets(tile, [Vector3(-0.22,0.072,-0.16),Vector3(0.22,0.072,0.16)], Vector3.UP, steel)
	for side in [-1.0, 1.0]:
		Geometry.plate(self, Vector3(0.78, 0.13, 4.75), Vector3(side * 1.52, 1.19, 0), armor, 0.025)
		for i in range(5):
			var skirt := Geometry.plate(self, Vector3(0.13, 0.5, 0.83), Vector3(side * 1.87, 1.01, -1.76 + i * 0.88), armor, 0.035)
			Geometry.rivets(skirt, [Vector3(side*0.078,0.15,-0.28), Vector3(side*0.078,0.15,0.28), Vector3(side*0.078,-0.16,0.28)], Vector3(side,0,0), steel)
		var lamp_mat := material(Color("ffdea4"), 0.15, 0.2)
		lamp_mat.emission_enabled = true
		lamp_mat.emission = Color("ffc875")
		lamp_mat.emission_energy_multiplier = 2.5
		box(self, Vector3(0.32,0.25,0.15),Vector3(side*1.14,1.37,-2.13),dark)
		box(self, Vector3(0.23,0.14,0.03),Vector3(side*1.14,1.39,-2.22),lamp_mat)
		for z in [-2.38,2.38]:
			var eye := cylinder(self, 0.12, 0.12, Vector3(side*0.92,0.84,z), steel)
			eye.rotation.x = PI/2
			var hole := cylinder(self, 0.065, 0.125, eye.position, dark)
			hole.rotation.x = PI/2
		Geometry.plate(self,Vector3(0.42,0.23,1.05),Vector3(side*1.1,1.56,1.47),armor,0.04)
		for i in range(3):
			var exhaust := cylinder(self,0.11,0.22,Vector3(side*0.65,1.0,2.35+i*0.035),dark)
			exhaust.rotation.x = PI/2
	box(self,Vector3(1.48,0.09,1.04),Vector3(0,1.54,1.38),dark)
	for i in range(12):
		box(self,Vector3(1.36,0.03,0.038),Vector3(0,1.60,0.89+i*0.087),steel)
	# Tow cable and rear reflectors.
	for i in range(16):
		var cable := cylinder(self,0.027,0.19,Vector3(-1.2+i*0.16,0.71-0.13*sin(i/15.0*PI),2.40),steel)
		cable.rotation.z = PI/2
	for side in [-1.0,1.0]:
		box(self,Vector3(0.19,0.09,0.03),Vector3(side*1.13,1.17,2.30),material(Color("8f3525")))

func build_tracks() -> void:
	var rubber := material(Color("141917"), 0.03, 0.97)
	for side in [-1.0, 1.0]:
		for i in range(7):
			var z := -1.81 + i * 0.605
			var tire := cylinder(self, 0.405, 0.53, Vector3(side*1.54,0.60,z),rubber)
			tire.rotation.z = PI/2
			var wheel := cylinder(self,0.32,0.56,Vector3(side*1.54,0.60,z),armor)
			wheel.rotation.z = PI/2
			wheels.append(wheel)
			var hub := cylinder(wheel,0.10,0.64,Vector3.ZERO,steel)
			var bolts: Array[Vector3] = []
			for k in range(8):
				bolts.append(Vector3(cos(k*TAU/8)*0.22,-side*0.30,sin(k*TAU/8)*0.22))
			Geometry.rivets(wheel,bolts,Vector3(0,-side,0),steel)
			# A spoke makes wheel rotation visible.
			box(wheel,Vector3(0.44,0.015,0.045),Vector3(0,-side*0.29,0),steel)
		var batch := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var link := BoxMesh.new()
		link.size = Vector3(0.65,0.11,0.17)
		multi.mesh = link
		multi.instance_count = TRACK_LINKS
		batch.multimesh = multi
		batch.material_override = steel
		add_child(batch)
		track_batches.append(multi)

func build_turret() -> void:
	turret = Node3D.new()
	add_child(turret)
	turret.position = Vector3(0,1.65,-0.25)
	cylinder(turret,1.03,0.16,Vector3(0,-0.09,0),steel)
	Geometry.plate(turret,Vector3(2.22,0.68,2.12),Vector3(0,0.32,0.12),armor,0.15,0.17)
	for side in [-1.0,1.0]:
		for i in range(3):
			var cheek := Geometry.plate(turret,Vector3(0.48,0.53,0.66),Vector3(side*(0.91+i*0.045),0.30,-0.71+i*0.68),trim,0.05,0.05)
			cheek.rotation.z = side*deg_to_rad(-12)
			cheek.rotation.y = side*deg_to_rad(9)
			Geometry.rivets(cheek,[Vector3(side*0.25,0.16,-0.23),Vector3(side*0.25,-0.14,0.23)],Vector3(side,0,0),steel)
		for i in range(3):
			var launcher := cylinder(turret,0.07,0.35,Vector3(side*1.19,0.58,0.05+i*0.20),dark)
			launcher.rotation.z = side*0.85
			launcher.rotation.x = -0.45
		var number := Label3D.new()
		number.text = "07"
		number.font_size = 72
		number.pixel_size = 0.003
		number.modulate = Color("d7d6b3")
		number.outline_size = 0
		number.no_depth_test = false
		number.shaded = true
		turret.add_child(number)
		number.position = Vector3(side*1.24,0.28,0.72)
		number.rotation.y = side*PI/2
	cylinder(turret,0.34,0.15,Vector3(0.44,0.75,0.40),trim)
	cylinder(turret,0.27,0.035,Vector3(0.44,0.85,0.40),armor)
	box(turret,Vector3(0.17,0.07,0.04),Vector3(0.44,0.9,0.4),steel)
	var glass := material(Color("274e58"),0.65,0.15)
	for i in range(4):
		var angle := i*TAU/4
		var scope := box(turret,Vector3(0.14,0.09,0.055),Vector3(0.44+sin(angle)*0.32,0.8,0.4+cos(angle)*0.32),glass)
		scope.rotation.y = angle
	Geometry.plate(turret,Vector3(0.4,0.25,0.46),Vector3(-0.5,0.74,-0.34),armor,0.04)
	box(turret,Vector3(0.28,0.12,0.03),Vector3(-0.5,0.76,-0.58),glass)
	for x in [-0.8,0.80]:
		cylinder(turret,0.05,0.12,Vector3(x,0.73,0.84),steel)
		cylinder(turret,0.011,1.45 if x<0 else 1.08,Vector3(x,1.47 if x<0 else 1.28,0.84),dark)
	Geometry.plate(turret,Vector3(1.85,0.43,0.5),Vector3(0,0.26,1.33),armor,0.04)
	for x in [-0.65,0.0,0.65]:
		box(turret,Vector3(0.04,0.44,0.53),Vector3(x,0.26,1.33),dark)
	barrel = Node3D.new()
	turret.add_child(barrel)
	barrel.position = Vector3(0,0.38,-0.94)
	Geometry.plate(barrel,Vector3(0.72,0.5,0.54),Vector3.ZERO,trim,0.07)
	gun_slide = Node3D.new()
	barrel.add_child(gun_slide)
	var tube := cylinder(gun_slide,0.113,3.55,Vector3(0,0,-1.78),armor)
	tube.rotation.x = PI/2
	for z in [-0.35,-0.76,-1.35,-2.0,-2.62,-3.29]:
		var collar := cylinder(gun_slide,0.14 if z>-1 else 0.125,0.10,Vector3(0,0,z),steel)
		collar.rotation.x = PI/2
	var extractor := cylinder(gun_slide,0.175,0.50,Vector3(0,0,-1.25),trim)
	extractor.rotation.x = PI/2
	# A real open muzzle: TorusMesh surrounds a recessed dark bore.
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.084
	torus.outer_radius = 0.145
	torus.rings = 24
	torus.ring_segments = 10
	rim.mesh = torus
	rim.material_override = steel
	gun_slide.add_child(rim)
	rim.position.z = -3.62
	rim.rotation.x = PI/2
	var bore := cylinder(gun_slide,0.086,0.01,Vector3(0,0,-3.57),dark)
	bore.rotation.x = PI/2
	muzzle = Marker3D.new()
	barrel.add_child(muzzle)
	muzzle.position.z = -3.72

func track_transform(distance: float, side: float) -> Transform3D:
	var d := fposmod(distance, TRACK_LENGTH)
	var y := 0.13
	var z := 0.0
	var angle := 0.0
	var straight := 2 * TRACK_HALF_LENGTH
	if d < straight:
		z = -TRACK_HALF_LENGTH + d
	elif d < straight + PI*TRACK_RADIUS:
		var theta := -PI/2 + (d-straight)/TRACK_RADIUS
		y = 0.60 + TRACK_RADIUS*sin(theta)
		z = TRACK_HALF_LENGTH + TRACK_RADIUS*cos(theta)
		angle = -theta-PI/2
	elif d < 2*straight + PI*TRACK_RADIUS:
		y = 1.07
		z = TRACK_HALF_LENGTH-(d-straight-PI*TRACK_RADIUS)
		angle = PI
	else:
		var theta := PI/2+(d-2*straight-PI*TRACK_RADIUS)/TRACK_RADIUS
		y = 0.60 + TRACK_RADIUS*sin(theta)
		z = -TRACK_HALF_LENGTH + TRACK_RADIUS*cos(theta)
		angle = -theta-PI/2
	return Transform3D(Basis(Vector3.RIGHT,angle),Vector3(side*1.54,y,z))

func kick_recoil() -> void:
	recoil = 0.30
	gun_slide.position.z = recoil

func animate(speed: float, dt: float, turn_rate: float = 0.0) -> void:
	recoil = move_toward(recoil, 0, dt * 0.75)
	gun_slide.position.z = recoil
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		var belt_speed := speed + side*turn_rate*1.54
		track_phases[side_index] += belt_speed*dt
		for i in range(TRACK_LINKS):
			track_batches[side_index].set_instance_transform(i,track_transform(i*TRACK_LENGTH/TRACK_LINKS+track_phases[side_index],side))
		for i in range(7):
			wheels[side_index*7+i].rotate_object_local(Vector3.UP,belt_speed*dt/0.405)
