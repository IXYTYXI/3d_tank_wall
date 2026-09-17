extends RefCounted

# Merge immobile parts into one draw per material; leave articulated nodes intact.
static func bake(root: Node3D, excluded: Array[Node] = []) -> void:
	var surfaces: Dictionary = {}
	var consumed: Array[Node] = []
	gather(root,root,excluded,surfaces,consumed)
	for node in consumed:
		if is_instance_valid(node):
			node.free()
	for entry in surfaces.values():
		var item := MeshInstance3D.new()
		item.mesh = entry.tool.commit()
		item.material_override = entry.material
		root.add_child(item)

static func gather(node: Node3D, root: Node3D, excluded: Array[Node], surfaces: Dictionary, consumed: Array[Node]) -> void:
	if node in excluded:
		return
	for child in node.get_children():
		if child is Node3D:
			gather(child,root,excluded,surfaces,consumed)
	var relative := root.global_transform.affine_inverse()*node.global_transform
	if node is MeshInstance3D:
		append(node.mesh,node.material_override,relative,surfaces)
		consumed.append(node)
	elif node is MultiMeshInstance3D:
		for i in range(node.multimesh.instance_count):
			append(node.multimesh.mesh,node.material_override,relative*node.multimesh.get_instance_transform(i),surfaces)
		consumed.append(node)

static func append(mesh: Mesh, mat: Material, pose: Transform3D, surfaces: Dictionary) -> void:
	for i in range(mesh.get_surface_count()):
		var material: Material = mat if mat else mesh.surface_get_material(i)
		var key: int = material.get_instance_id() if material else 0
		if not surfaces.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key] = {"tool":st,"material":material}
		# SurfaceTool does not synthesize indices for earlier unindexed parts.
		# Normalize first, or later cylinders make the existing plates disappear.
		var source := mesh
		var surface := i
		var arrays := mesh.surface_get_arrays(i)
		if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
			var indices := PackedInt32Array()
			indices.resize(arrays[Mesh.ARRAY_VERTEX].size())
			for j in range(indices.size()):
				indices[j] = j
			arrays[Mesh.ARRAY_INDEX] = indices
			var indexed := ArrayMesh.new()
			indexed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			source = indexed
			surface = 0
		surfaces[key].tool.append_from(source,surface,pose)

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color = Color.WHITE) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.dot(outward)<0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for point in [a,b,c]:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(point)

static func mesh_node(parent: Node3D, st: SurfaceTool, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = st.commit()
	item.material_override = mat
	parent.add_child(item)
	return item
