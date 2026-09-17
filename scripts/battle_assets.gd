extends RefCounted
const Parts = preload("res://scripts/tank_visual.gd")
const Geometry = preload("res://scripts/armor_geometry.gd")
const Meshes = preload("res://scripts/model_mesh.gd")
const Surface = preload("res://shaders/weathered_surface.gdshader")
static var cache: Dictionary = {}
static var palette: Dictionary = {}

static func create(kind: String, parent: Node3D, seed_value: int = 0) -> Node3D:
	match kind:
		"pine": return pine(parent,seed_value)
		"rock": return rock(parent,seed_value)
		"barrier": return barrier(parent,seed_value)
		"dragon_tooth": return dragon_tooth(parent,seed_value)
		"hedgehog": return hedgehog(parent,seed_value)
		"headquarters": return headquarters(parent,seed_value)
	return Node3D.new()

static func mat(key: String, color: String, metal: float = 0.0, hazard: bool = false) -> Material:
	if not palette.has(key):
		var material := ShaderMaterial.new()
		material.shader = Surface
		material.set_shader_parameter("base_color",Color(color))
		material.set_shader_parameter("metal",metal)
		material.set_shader_parameter("hazard",hazard)
		palette[key] = material
	return palette[key]

static func begin(parent: Node3D, kind: String, seed_value: int) -> Node3D:
	var node := Node3D.new()
	node.name = kind
	node.set_meta("asset_kind",kind)
	parent.add_child(node)
	var key := kind+str(seed_value)
	if cache.has(key):
		for data in cache[key]:
			var mesh := MeshInstance3D.new()
			mesh.mesh = data[0]
			mesh.material_override = data[1]
			node.add_child(mesh)
		node.set_meta("cached",true)
	return node

static func finish(node: Node3D, seed_value: int) -> Node3D:
	Meshes.bake(node)
	var entries: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			entries.append([child.mesh,child.material_override])
	cache[str(node.get_meta("asset_kind"))+str(seed_value)] = entries
	return node

static func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, tip: float = -1.0, segments: int = 8) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if tip<0 else tip
	mesh.height = a.distance_to(b)
	mesh.radial_segments = segments
	item.mesh = mesh
	item.material_override = material
	parent.add_child(item)
	item.position = (a+b)*0.5
	item.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	return item

static func pine(parent: Node3D, seed_value: int = 0) -> Node3D:
	var root := begin(parent,"pine",seed_value)
	if root.has_meta("cached"):
		return root
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_value%100)*773+81
	var far := seed_value>=100
	var tier_count := 8 if far else 14
	var branch_count := 5 if far else 7
	var twig_count := 4 if far else 6
	var feather_count := 2 if far else 4
	var bark := mat("bark","504538")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown_height := rng.randf_range(8.5,11.5)
	var lean := Vector3(rng.randf_range(-0.45,0.45),0,rng.randf_range(-0.4,0.4))
	for i in range(7):
		var a := Vector3.UP*crown_height*i/7.0+lean*pow(i/7.0,2)
		var b := Vector3.UP*crown_height*(i+1)/7.0+lean*pow((i+1)/7.0,2)
		tube(root,a,b,0.24*(1-i/8.0),bark,0.24*(1-(i+1)/8.0),9)
	for tier in range(tier_count):
		var y := 1.7+tier*(crown_height-1.9)/float(tier_count)
		var radius := (crown_height-y)*0.31
		for branch in range(branch_count):
			var angle := branch*TAU/branch_count+tier*1.07+rng.randf_range(-0.18,0.18)
			var outward := Vector3(cos(angle),0,sin(angle))
			var sideways := Vector3(-outward.z,0,outward.x)
			var start := Vector3(0,y+rng.randf_range(-0.20,0.20),0)+lean*pow(y/crown_height,2)
			var tip := start+outward*radius*rng.randf_range(0.75,1.18)+Vector3(0,-0.35,0)
			tube(root,start,tip,0.045,bark,0.008,5)
			for twig in range(twig_count):
				var t := 0.18+twig*0.87/float(twig_count)
				var center := start.lerp(tip,t)
				for side in [-1.0,1.0]:
					var end: Vector3 = center+outward*radius*0.23+sideways*side*radius*(0.37*(1-t)+0.06)+Vector3(0,0.14,0)
					var axis: Vector3 = end-center
					var width := 0.08+radius*0.055*(1-t)
					var color := Color("334c35").lightened(rng.randf_range(-0.15,0.2))
					for feather in range(feather_count):
						var f := feather/float(feather_count)
						var middle: Vector3 = center+axis*f
						var point: Vector3 = center+axis*minf(1.1,f+0.46)+Vector3(0,-0.14-radius*0.045,0)
						var spread := sideways*width*(1-f*0.75)
						Meshes.triangle(st,middle-spread,point,middle+spread,Vector3.UP,color)
						Meshes.triangle(st,middle-Vector3.UP*width*0.5,point,middle+Vector3.UP*width*0.5,outward,color.darkened(0.10))
	var needles := StandardMaterial3D.new()
	needles.vertex_color_use_as_albedo = true
	needles.vertex_color_is_srgb = true
	needles.cull_mode = BaseMaterial3D.CULL_DISABLED
	needles.roughness = 0.94
	Meshes.mesh_node(root,st,needles)
	return finish(root,seed_value)

static func rock(parent: Node3D, seed_value: int = 0) -> Node3D:
	var root := begin(parent,"rock",seed_value)
	if root.has_meta("cached"):
		return root
	var rng := RandomNumberGenerator.new()
	rng.seed = 912+seed_value*917
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for row in range(6):
		var vertices := PackedVector3Array()
		var y: float = [-0.45,-0.22,0.04,0.25,0.43,0.50][row]
		var radius: float = [0.37,0.51,0.50,0.43,0.28,0.05][row]
		for col in range(11):
			var angle := col*TAU/11+0.12*(row%2)
			var r := radius*rng.randf_range(0.76,1.14)
			vertices.append(Vector3(cos(angle)*r+row*0.008,y+rng.randf_range(-0.055,0.055),sin(angle)*r))
		rings.append(vertices)
	for row in range(5):
		for col in range(11):
			var next := (col+1)%11
			var a := rings[row][col]
			var b := rings[row][next]
			var c := rings[row+1][col]
			var d := rings[row+1][next]
			Meshes.triangle(st,a,b,c,(a+b+c).normalized())
			Meshes.triangle(st,b,d,c,(b+d+c).normalized())
	for col in range(11):
		Meshes.triangle(st,Vector3(0,-0.5,0),rings[0][col],rings[0][(col+1)%11],Vector3.DOWN)
		Meshes.triangle(st,Vector3(0,0.52,0),rings[5][col],rings[5][(col+1)%11],Vector3.UP)
	Meshes.mesh_node(root,st,mat("rock","626d63"))
	return finish(root,seed_value)

# Extruded bevelled Jersey profile, not a box: wide feet and sloping shoulders.
static func barrier(parent: Node3D, seed_value: int = 0) -> Node3D:
	var root := begin(parent,"barrier",seed_value)
	if root.has_meta("cached"):
		return root
	var profile := [Vector2(-0.75,0),Vector2(0.75,0),Vector2(0.75,0.22),Vector2(0.34,0.76),Vector2(0.23,1.48),Vector2(-0.23,1.48),Vector2(-0.34,0.76),Vector2(-0.75,0.22)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(profile.size()):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i+1)%profile.size()]
		var p := Vector3(-1.7,a.y,a.x)
		var q := Vector3(1.7,a.y,a.x)
		var r := Vector3(-1.7,b.y,b.x)
		var t := Vector3(1.7,b.y,b.x)
		var normal := Vector3(0,(a.y+b.y)*0.5-0.7,(a.x+b.x)*0.5)
		Meshes.triangle(st,p,q,r,normal)
		Meshes.triangle(st,q,t,r,normal)
		Meshes.triangle(st,Vector3(-1.7,0.7,0),p,r,Vector3.LEFT)
		Meshes.triangle(st,Vector3(1.7,0.7,0),q,t,Vector3.RIGHT)
	Meshes.mesh_node(root,st,mat("hazard","989785",0,true))
	var metal := mat("rust","58453a",0.55)
	for x in [-1.16,1.16]:
		for side in [-1.0,1.0]:
			tube(root,Vector3(x,1.47,-0.11),Vector3(x,1.62,-0.11),0.023,metal)
			tube(root,Vector3(x,1.62,-0.11),Vector3(x,1.62,0.11),0.023,metal)
			tube(root,Vector3(x,1.62,0.11),Vector3(x,1.47,0.11),0.023,metal)
			Geometry.plate(root,Vector3(0.26,0.10,0.16),Vector3(x,0.15,side*0.77),metal,0.025)
	return finish(root,seed_value)

static func dragon_tooth(parent: Node3D, seed_value: int = 0) -> Node3D:
	var root := begin(parent,"dragon_tooth",seed_value)
	if root.has_meta("cached"):
		return root
	var concrete := mat("concrete","818779")
	Geometry.plate(root,Vector3(1.95,0.22,1.95),Vector3(0,0.08,0),concrete,0.08)
	var tooth := Geometry.plate(root,Vector3(1.60,1.85,1.60),Vector3(0,1.08,0),concrete,0.10,0.53)
	tooth.rotation.z = 0.035*(seed_value%3-1)
	var iron := mat("rust","58453a",0.55)
	tube(root,Vector3(-0.12,1.95,0),Vector3(-0.12,2.10,0),0.028,iron)
	tube(root,Vector3(-0.12,2.10,0),Vector3(0.12,2.10,0),0.028,iron)
	tube(root,Vector3(0.12,2.10,0),Vector3(0.12,1.95,0),0.028,iron)
	for i in range(5):
		var chip := rock(root,i)
		chip.scale = Vector3(0.18,0.12,0.23)
		chip.position = Vector3(-0.8+i*0.38,0.12,0.91)
	return finish(root,seed_value)

static func hedgehog(parent: Node3D, seed_value: int = 0) -> Node3D:
	var root := begin(parent,"hedgehog",seed_value)
	if root.has_meta("cached"):
		return root
	var steel := mat("obstacle_steel","554e41",0.72)
	var bolts := mat("bolt","91816c",0.65)
	for angles in [Vector3(0,0,PI/4),Vector3(0,0,-PI/4),Vector3(PI/2,0,0)]:
		var beam := Node3D.new()
		root.add_child(beam)
		beam.position.y = 1.12
		beam.rotation = angles
		Geometry.plate(beam,Vector3(0.09,3.0,0.26),Vector3.ZERO,steel,0.01)
		for z in [-0.17,0.17]:
			Geometry.plate(beam,Vector3(0.36,3.0,0.055),Vector3(0,0,z),steel,0.015)
			var points: Array[Vector3] = []
			for x in [-0.12,0.12]:
				for y in [-0.19,0.19]:
					points.append(Vector3(x,y,z+signf(z)*0.038))
			Geometry.rivets(beam,points,Vector3(0,0,signf(z)),bolts)
		Geometry.plate(beam,Vector3(0.47,0.55,0.045),Vector3(0,0,0.205),steel,0.02)
	return finish(root,seed_value)

static func sandbag(parent: Node3D, pos: Vector3, angle: float = 0.0) -> void:
	var item := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 12
	mesh.rings = 6
	item.mesh = mesh
	item.material_override = mat("canvas","8c8866")
	parent.add_child(item)
	item.position = pos
	item.scale = Vector3(1.05,0.36,0.55)
	item.rotation.y = angle
	# Pinched end ties distinguish bags from stacked bricks.
	for side in [-1.0,1.0]:
		tube(parent,pos+Vector3(side*0.43,-0.03,0).rotated(Vector3.UP,angle),pos+Vector3(side*0.55,0.01,0).rotated(Vector3.UP,angle),0.065,mat("canvas","8c8866"),0.025)

static func headquarters(parent: Node3D, seed_value: int = 0) -> Node3D:
	var root := begin(parent,"headquarters",seed_value)
	if root.has_meta("cached"):
		return root
	var concrete := mat("hq_concrete","687267")
	var olive := mat("hq_steel","485a4d",0.45)
	var iron := mat("bolt","91816c",0.65)
	var dark := mat("dark","172320",0.20)
	Geometry.plate(root,Vector3(9.6,0.3,7.6),Vector3(0,0.05,0),concrete,0.08)
	Geometry.plate(root,Vector3(8.8,3.0,6.8),Vector3(0,1.6,0),concrete,0.19,0.22)
	Geometry.plate(root,Vector3(9.3,0.38,7.3),Vector3(0,3.22,0),concrete,0.13,0.11)
	# Buttressed side walls, protected viewing slits and a rear service ladder.
	for side in [-1.0,1.0]:
		for z in [-2.45,0.0,2.45]:
			Geometry.plate(root,Vector3(0.46,2.7,0.55),Vector3(side*4.30,1.5,z),concrete,0.09,0.10)
		for z in [-1.2,1.2]:
			Geometry.plate(root,Vector3(0.24,0.48,1.05),Vector3(side*4.22,2.0,z),olive,0.04)
			Geometry.plate(root,Vector3(0.04,0.17,0.82),Vector3(side*4.36,2.04,z),dark,0.012,0.001)
	for x in [-1.65,-0.95]:
		tube(root,Vector3(x,0.4,3.53),Vector3(x,3.7,3.53),0.035,iron)
	for step in range(10):
		tube(root,Vector3(-1.65,0.5+step*0.32,3.53),Vector3(-0.95,0.5+step*0.32,3.53),0.025,iron)
	# Split armored doors, frame, hinges, inspection ports and steps.
	Geometry.plate(root,Vector3(2.55,2.35,0.32),Vector3(0,1.30,-3.35),dark,0.07)
	for side in [-1.0,1.0]:
		Geometry.plate(root,Vector3(1.10,2.08,0.13),Vector3(side*0.58,1.24,-3.57),olive,0.045)
		for y in [0.5,1.9]:
			tube(root,Vector3(side*1.04,y-0.11,-3.69),Vector3(side*1.04,y+0.11,-3.69),0.055,iron)
		tube(root,Vector3(side*0.21,1.03,-3.71),Vector3(side*0.21,1.36,-3.71),0.026,iron)
		Geometry.plate(root,Vector3(0.42,0.12,0.07),Vector3(side*0.58,1.77,-3.68),dark,0.015)
		Geometry.plate(root,Vector3(1.70,0.64,0.25),Vector3(side*2.78,2.01,-3.28),olive,0.08)
		Geometry.plate(root,Vector3(1.36,0.26,0.035),Vector3(side*2.78,2.04,-3.43),dark,0.025)
		for x in range(5):
			tube(root,Vector3(side*2.78-0.56+x*0.28,1.9,-3.48),Vector3(side*2.78-0.56+x*0.28,2.18,-3.48),0.018,iron)
	for i in range(3):
		Geometry.plate(root,Vector3(2.8,0.17,0.55),Vector3(0,0.04+i*0.13,-4.45+i*0.46),concrete,0.04)
	# Sandbag parapet and entrance flanks.
	for row in range(3):
		for i in range(9):
			sandbag(root,Vector3(-4.0+i*0.99+(row%2)*0.20,3.55+row*0.31,2.9),0.03*sin(i))
		for side in [-1.0,1.0]:
			for i in range(5):
				sandbag(root,Vector3(side*3.55,0.36+row*0.30,-4.1+i*0.54),PI/2)
	# Weather canopy above doorway.
	var canopy := SurfaceTool.new()
	canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		Meshes.triangle(canopy,Vector3(0,3.08,-3.4),Vector3(side*1.75,2.75,-3.4),Vector3(side*1.75,2.61,-4.75),Vector3.UP)
		Meshes.triangle(canopy,Vector3(0,3.08,-3.4),Vector3(side*1.75,2.61,-4.75),Vector3(0,2.91,-4.75),Vector3.UP)
	Meshes.mesh_node(root,canopy,mat("canopy","57674b"))
	for side in [-1.0,1.0]:
		tube(root,Vector3(side*1.72,0.25,-4.69),Vector3(side*1.72,2.62,-4.69),0.035,olive)
	# Rooftop lattice radio mast.
	var origin := Vector3(-2.8,3.43,1.6)
	for level in range(5):
		for corner in range(3):
			var angle := corner*TAU/3
			var next := (corner+1)*TAU/3
			var a := origin+Vector3(cos(angle)*0.43,level*0.9,sin(angle)*0.43)
			var b := origin+Vector3(cos(angle)*0.43,(level+1)*0.9,sin(angle)*0.43)
			var c := origin+Vector3(cos(next)*0.43,(level+1)*0.9,sin(next)*0.43)
			tube(root,a,b,0.035,iron)
			tube(root,a,c,0.017,iron)
			tube(root,b,c,0.018,iron)
	tube(root,origin+Vector3.UP*4.5,origin+Vector3.UP*6,0.023,iron)
	for height_value in [4.25,5.0]:
		tube(root,origin+Vector3(-1,height_value,0),origin+Vector3(1,height_value,0),0.024,iron)
	# Parabolic satellite reflector with feed arm, tilted toward the sky.
	var dish := Node3D.new()
	root.add_child(dish)
	dish.position = Vector3(2.0,4.55,0.8)
	dish.rotation.x = -0.65
	var reflector := SurfaceTool.new()
	reflector.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(5):
		for segment in range(32):
			var a := segment*TAU/32
			var b := (segment+1)*TAU/32
			var r := ring*0.24
			var t := (ring+1)*0.24
			var p := Vector3(cos(a)*r,0.32*r*r,sin(a)*r)
			var q := Vector3(cos(b)*r,0.32*r*r,sin(b)*r)
			var u := Vector3(cos(a)*t,0.32*t*t,sin(a)*t)
			var v := Vector3(cos(b)*t,0.32*t*t,sin(b)*t)
			Meshes.triangle(reflector,p,q,u,Vector3.UP)
			Meshes.triangle(reflector,q,v,u,Vector3.UP)
	var dish_mat := Parts.material(Color("b2b5a2"),0.5,0.62)
	dish_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	Meshes.mesh_node(dish,reflector,dish_mat)
	for side in [-1.0,1.0]:
		tube(dish,Vector3(side*1.02,0.34,0),Vector3(0,1.03,0),0.025,iron)
	tube(dish,Vector3(0,0.97,0),Vector3(0,1.13,0),0.09,dark)
	tube(root,Vector3(2,3.40,0.8),Vector3(2,4.55,0.8),0.12,olive)
	# Creased command pennant on its own pole, visible above the roofline.
	tube(root,Vector3(3.85,3.35,2.4),Vector3(3.85,7.0,2.4),0.028,iron)
	var flag := SurfaceTool.new()
	flag.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		var x := 3.85+i*0.17
		var next_x := x+0.17
		var z := 2.4+sin(i*0.7)*0.13
		var next_z := 2.4+sin((i+1)*0.7)*0.13
		Meshes.triangle(flag,Vector3(x,6.15,z),Vector3(next_x,6.15,next_z),Vector3(x,6.90,z),Vector3.FORWARD)
		Meshes.triangle(flag,Vector3(next_x,6.15,next_z),Vector3(next_x,6.90,next_z),Vector3(x,6.90,z),Vector3.FORWARD)
	var cloth := Parts.material(Color("447a70"),0,0.95)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	Meshes.mesh_node(root,flag,cloth)
	# Rear air-handling vents and rooftop armored access hatch.
	Geometry.plate(root,Vector3(1.55,0.21,1.5),Vector3(0,3.50,1.5),olive,0.07)
	for i in range(10):
		Geometry.plate(root,Vector3(1.23,0.04,0.05),Vector3(0,3.63,0.97+i*0.12),dark,0.01)
	for side in [-1.0,1.0]:
		tube(root,Vector3(side*3.8,3.3,1.3),Vector3(side*3.8,3.85,1.3),0.17,olive)
		Geometry.plate(root,Vector3(0.6,0.10,0.6),Vector3(side*3.8,3.90,1.3),olive,0.04)
	return finish(root,seed_value)

static func ridgeline(parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for ring in range(8):
		var points := PackedVector3Array()
		for sector in range(97):
			var angle := sector*TAU/96
			var radius := 140+ring*43.0+sin(angle*7+ring)*12
			var ridge: float = [-8,8,30,52,44,26,6,-10][ring]
			var height_value := ridge*(0.80+sin(angle*11+ring*0.25)*0.28+cos(angle*17)*0.19)
			points.append(Vector3(cos(angle)*radius,height_value,sin(angle)*radius))
		rings.append(points)
	for ring in range(7):
		for sector in range(96):
			Meshes.triangle(st,rings[ring][sector],rings[ring+1][sector],rings[ring][sector+1],Vector3.UP)
			Meshes.triangle(st,rings[ring][sector+1],rings[ring+1][sector],rings[ring+1][sector+1],Vector3.UP)
	st.generate_normals()
	var mountain := ShaderMaterial.new()
	mountain.shader = preload("res://shaders/ridgeline.gdshader")
	Meshes.mesh_node(parent,st,mountain)
