extends "res://scripts/tank_visual.gd"
const Meshes = preload("res://scripts/model_mesh.gd")
var variant := "标准坦克"

func _ready() -> void:
	var color := Color("826647")
	if variant=="轻型坦克":
		color = Color("97916a")
	elif variant=="重型坦克":
		color = Color("66554b")
	armor = paint(color,0.85)
	armor.set_shader_parameter("patch_color",Color("403a31"))
	trim = paint(color.lightened(0.12),0.30)
	dark = material(Color("161b1b"),0.15,0.93)
	steel = material(Color("665e50"),0.72,0.52)
	build_hull()
	build_tracks()
	build_turret()
	# Broad spaced armor vs compact scout turret create distinct silhouettes.
	if variant=="重型坦克":
		for side in [-1.0,1.0]:
			for row in range(2):
				for i in range(4):
					var block := Geometry.plate(turret,Vector3(0.29,0.27,0.44),Vector3(side*1.22,0.16+row*0.29,-0.65+i*0.45),trim,0.045)
					block.rotation.z = side*-0.14
			for i in range(6):
				Geometry.plate(self,Vector3(0.20,0.43,0.63),Vector3(side*1.92,1.20,-1.75+i*0.69),trim,0.035)
		Geometry.plate(turret,Vector3(2.05,0.30,0.80),Vector3(0,0.52,1.40),armor,0.09)
	elif variant=="轻型坦克":
		turret.scale = Vector3(0.87,0.82,0.94)
		# External fuel drums, straps, and a long reconnaissance whip.
		for side in [-1.0,1.0]:
			var drum := cylinder(self,0.27,1.13,Vector3(side*0.84,1.60,2.03),trim)
			drum.rotation.z = PI/2
			for offset in [-0.38,0.38]:
				var band := cylinder(self,0.285,0.065,Vector3(side*0.84+offset,1.60,2.03),steel)
				band.rotation.z = PI/2
		cylinder(turret,0.012,2.3,Vector3(-0.72,1.94,0.8),dark)
	else:
		# Welded bustle rack with canvas load and retaining rails.
		Geometry.plate(turret,Vector3(1.60,0.40,0.57),Vector3(0,0.65,1.39),trim,0.11)
		for i in range(6):
			box(turret,Vector3(0.025,0.47,0.025),Vector3(-0.83+i*0.33,0.50,1.73),steel)
		box(turret,Vector3(1.80,0.025,0.025),Vector3(0,0.74,1.73),steel)
	for node in turret.get_children():
		if node is Label3D:
			node.text = "31" if variant=="重型坦克" else "12" if variant=="轻型坦克" else "24"
			node.modulate = Color("f4d0a6")
	# Enemy markings are painted plates, not floating red primitives.
	var marking := material(Color("a24c35"),0.25)
	for side in [-1.0,1.0]:
		Geometry.plate(self,Vector3(0.024,0.24,0.62),Vector3(side*2.035,1.22,0.0),marking,0.005)
	var hull_exclusions: Array[Node] = [turret]
	for wheel in wheels:
		hull_exclusions.append(wheel)
	for node in get_children():
		if node is MultiMeshInstance3D and node.multimesh in track_batches:
			hull_exclusions.append(node)
	Meshes.bake(self,hull_exclusions)
	var turret_exclusions: Array[Node] = [barrel]
	Meshes.bake(turret,turret_exclusions)
	var barrel_exclusions: Array[Node] = [gun_slide,muzzle]
	Meshes.bake(barrel,barrel_exclusions)
	Meshes.bake(gun_slide)
	animate(0,0)
