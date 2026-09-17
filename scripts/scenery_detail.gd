extends Node3D
## Decorative, deterministic detail. No physics bodies or navigation obstacles.
const Assets = preload("res://scripts/battle_assets.gd")

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90421
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(9):
		var angle := blade*2.399
		var origin := Vector3(cos(angle),0,sin(angle))*0.16
		var side := Vector3(cos(angle+0.7),0,sin(angle+0.7))*0.035
		var tip := origin+Vector3(cos(angle)*0.12,0.26+(blade%4)*0.08,sin(angle)*0.12)
		for point in [origin-side,tip,origin+side]:
			st.set_normal(Vector3.UP)
			st.set_color(Color("6c7050") if point==tip else Color("343e22"))
			st.add_vertex(point)
	var grass_mat := StandardMaterial3D.new()
	grass_mat.vertex_color_use_as_albedo = true
	grass_mat.vertex_color_is_srgb = true
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mat.roughness = 0.95
	var grass_mesh := st.commit()
	grass_mesh.surface_set_material(0,grass_mat)
	var stone_mesh := SphereMesh.new()
	stone_mesh.radial_segments = 7
	stone_mesh.rings = 3
	stone_mesh.radius = 0.10
	stone_mesh.height = 0.12
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color("4d4b42")
	stone_mat.roughness = 0.93
	stone_mesh.material = stone_mat
	# Spatial chunks permit actual frustum/distance culling of the MultiMeshes.
	for cz in range(-3,4):
		for cx in range(-3,4):
			var grass: Array[Transform3D] = []
			var stones: Array[Transform3D] = []
			var chunk := Vector3(cx*30,0,cz*30)
			for i in range(190):
				var x := chunk.x+rng.randf_range(-15,15)
				var z := chunk.z+rng.randf_range(-15,15)
				var road_distance := absf(x-4*sin(z*0.04))
				var point := Vector3(x,get_parent().height(x,z)-0.025,z)-chunk
				var size := rng.randf_range(0.65,1.5)
				var pose := Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*size),point)
				if road_distance>4.5 and sin(x*0.36)+cos(z*0.26)>-0.6:
					grass.append(pose)
				elif i%3==0:
					stones.append(pose)
			batch(grass_mesh,grass,chunk,65)
			batch(stone_mesh,stones,chunk,55)
	# Low-detail forest skirt outside the playable boundary hides the bare mountain foot.
	for i in range(140):
		var angle := rng.randf_range(0,TAU)
		var radius := rng.randf_range(153,169)
		var tree := Assets.pine(self,100+i%6)
		var inner_radius := 140+sin(angle*7)*12
		var outer_radius := 183+sin(angle*7+1)*12
		var inner_height := -8*(0.80+sin(angle*11)*0.28+cos(angle*17)*0.19)
		var outer_height := 8*(0.80+sin(angle*11+0.25)*0.28+cos(angle*17)*0.19)
		var ground_height := lerpf(inner_height,outer_height,(radius-inner_radius)/(outer_radius-inner_radius))-0.7
		tree.position = Vector3(cos(angle)*radius,ground_height,sin(angle)*radius)
		tree.rotation.y = angle
		tree.scale = Vector3.ONE*rng.randf_range(0.85,1.7)
		for child in tree.get_children():
			if child is GeometryInstance3D:
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func batch(mesh: Mesh, poses: Array[Transform3D], position_value: Vector3, distance: float) -> void:
	if poses.is_empty():
		return
	var item := MultiMeshInstance3D.new()
	item.multimesh = MultiMesh.new()
	item.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	item.multimesh.mesh = mesh
	item.multimesh.instance_count = poses.size()
	for i in range(poses.size()):
		item.multimesh.set_instance_transform(i,poses[i])
	item.position = position_value
	item.visibility_range_end = distance
	item.visibility_range_end_margin = 10
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
