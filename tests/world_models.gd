extends SceneTree
var failures := 0
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok:
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists("res://scripts/battle_assets.gd"),"Battlefield uses purpose-built environment models")
	if failures:
		quit(1)
		return
	var assets = load("res://scripts/battle_assets.gd")
	var stage := Node3D.new()
	root.add_child(stage)
	for kind in ["pine","rock","barrier","dragon_tooth","hedgehog","headquarters"]:
		var model: Node3D = assets.call(kind,stage,2)
		check(model.has_meta("asset_kind") and model.get_meta("asset_kind")==kind,"Purpose-built "+kind+" model exists")
		var count := 0
		var vertices := 0
		for node in model.get_children():
			if node is MeshInstance3D:
				count += 1
				for surface in range(node.mesh.get_surface_count()):
					vertices += node.mesh.surface_get_array_len(surface)
		check(vertices>180 and count<=14,"Detailed "+kind+" uses bounded material batches")
		model.queue_free()
	var merged := Node3D.new()
	stage.add_child(merged)
	var parts = load("res://scripts/tank_visual.gd")
	var shared: Material = parts.material(Color.WHITE)
	load("res://scripts/armor_geometry.gd").plate(merged,Vector3(2,1,2),Vector3.ZERO,shared)
	parts.cylinder(merged,0.2,1,Vector3.UP,shared)
	var triangles := 0
	for node in merged.get_children():
		var mesh: Mesh = node.mesh
		var arrays: Array = mesh.surface_get_arrays(0)
		triangles += arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()
	load("res://scripts/model_mesh.gd").bake(merged)
	var result: Mesh = merged.get_child(0).mesh
	var actual: int = result.surface_get_array_index_len(0) if result.surface_get_array_index_len(0)>0 else result.surface_get_array_len(0)
	check(actual==triangles,"Static batching preserves both indexed cylinders and unindexed armor faces")
	var thin: MeshInstance3D = load("res://scripts/armor_geometry.gd").plate(stage,Vector3(0.02,0.3,0.5),Vector3.ZERO,shared)
	var thin_arrays: Array = thin.mesh.surface_get_arrays(0)
	var outward := true
	for i in range(thin_arrays[Mesh.ARRAY_VERTEX].size()):
		if thin_arrays[Mesh.ARRAY_VERTEX][i].dot(thin_arrays[Mesh.ARRAY_NORMAL][i])<=0:
			outward = false
	check(outward,"Thin armor markings and fittings never invert their bevel faces")
	var enemy = load("res://scripts/enemy_visual.gd").new()
	stage.add_child(enemy)
	check(enemy.track_batches.size()==2,"Enemy has two articulated track belts")
	await process_frame
	var phase: float = enemy.track_phases[0]
	var first: Transform3D = enemy.track_transform(phase,-1.0)
	enemy.animate(4,0.2,0)
	await process_frame
	check(enemy.track_phases[0]>phase and not enemy.track_transform(enemy.track_phases[0],-1.0).is_equal_approx(first),"Enemy track links move when driving")
	var muzzle: Vector3 = enemy.muzzle.position
	enemy.kick_recoil()
	enemy.animate(0,0.1,0)
	check(enemy.muzzle.position==muzzle,"Detailed enemy preserves physical muzzle under recoil")
	stage.queue_free()
	await process_frame
	print("WORLD MODELS RESULT: ",failures," failures")
	quit(0 if failures==0 else 1)
