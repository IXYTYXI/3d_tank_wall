extends RefCounted

# Octagonal rings form actual bevels and sloping plate silhouettes.
static func plate(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, bevel: float = 0.06, taper: float = 0.02) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := minf(bevel, minf(size.y * 0.3, minf(size.x, size.z) * 0.2))
	var safe_taper := clampf(taper,0,maxf(0,minf(size.x,size.z)*0.5-b-0.001))
	var rings: Array[PackedVector3Array] = []
	for layer in range(4):
		var inset: float = b if layer == 0 or layer == 3 else 0.0
		if layer >= 2:
			inset += safe_taper
		var hx := size.x * 0.5 - inset
		var hz := size.z * 0.5 - inset
		var cut := minf(bevel * 1.7, minf(hx, hz) * 0.45)
		var y: float = [-size.y * 0.5, -size.y * 0.5 + b, size.y * 0.5 - b, size.y * 0.5][layer]
		rings.append(PackedVector3Array([
			Vector3(-hx+cut,y,-hz),Vector3(hx-cut,y,-hz),Vector3(hx,y,-hz+cut),Vector3(hx,y,hz-cut),
			Vector3(hx-cut,y,hz),Vector3(-hx+cut,y,hz),Vector3(-hx,y,hz-cut),Vector3(-hx,y,-hz+cut)]))
	for layer in range(3):
		for i in range(8):
			var j := (i+1)%8
			for vertex in [rings[layer][i],rings[layer][j],rings[layer+1][i],rings[layer][j],rings[layer+1][j],rings[layer+1][i]]:
				st.add_vertex(vertex)
	for i in range(8):
		var j := (i+1)%8
		for vertex in [Vector3(0,size.y*0.5,0),rings[3][i],rings[3][j],Vector3(0,-size.y*0.5,0),rings[0][j],rings[0][i]]:
			st.add_vertex(vertex)
	st.generate_normals()
	var item := MeshInstance3D.new()
	item.mesh = st.commit()
	item.material_override = mat
	parent.add_child(item)
	item.position = pos
	return item

static func rivets(parent: Node3D, points: Array[Vector3], normal: Vector3, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.032
	mesh.bottom_radius = 0.038
	mesh.height = 0.027
	mesh.radial_segments = 6
	var batch := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = points.size()
	for i in range(points.size()):
		multi.set_instance_transform(i, Transform3D(Basis(Quaternion(Vector3.UP, normal)), points[i]))
	batch.multimesh = multi
	batch.material_override = mat
	parent.add_child(batch)
