extends SceneTree
var failed := 0

func check(value: bool, message: String) -> void:
	print("PASS " if value else "FAIL ", message)
	if not value:
		failed += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = load("res://scripts/tank_visual.gd").new()
	root.add_child(model)
	await process_frame
	if not model.has_method("kick_recoil"):
		check(false, "Tank needs independently animated tracks and recoil")
		model.queue_free()
		await process_frame
		quit(1)
		return
	var geometry = load("res://scripts/armor_geometry.gd")
	var sample: MeshInstance3D = geometry.plate(model, Vector3(3,1,4), Vector3.ZERO, model.armor)
	var arrays: Array = sample.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var outward := true
	for i in range(vertices.size()):
		if vertices[i].dot(normals[i]) <= 0:
			outward = false
	check(outward, "All armor faces point outward and remain visible from outside")
	sample.queue_free()
	var muzzle: Vector3 = model.muzzle.position
	model.kick_recoil()
	check(model.recoil > 0, "Shot starts visual recoil")
	check(model.muzzle.position.is_equal_approx(muzzle), "Recoil preserves logical muzzle position")
	model.animate(5.0, 0.1, 0.0)
	var phase: float = model.track_phases[0]
	check(phase > 0, "Forward motion advances track links")
	model.animate(-5.0, 0.1, 0.0)
	check(absf(model.track_phases[0]) < 0.001, "Reverse motion reverses track travel")
	model.animate(0.0, 0.1, 1.0)
	check(model.track_phases[0] * model.track_phases[1] < 0, "Pivot turn drives opposite tracks")
	for i in range(120):
		model.animate(0.0, 1.0 / 60.0, 0.0)
	check(model.recoil < 0.001, "Barrel returns after recoil")
	check(model.muzzle.position.is_equal_approx(muzzle), "Animation never offsets logical muzzle")
	var fx = load("res://scripts/battle_effects.gd").new()
	root.add_child(fx)
	fx.fire(Vector3.ZERO, Vector3.FORWARD)
	check(fx.flashes.size() == 1 and fx.particles.size() > 0, "Shot produces flash and smoke")
	var age: float = fx.particles[0].age
	await process_frame
	check(is_equal_approx(fx.particles[0].age, age), "Effects freeze without an explicit simulation tick")
	for i in range(15):
		fx.fire(Vector3.ZERO, Vector3.FORWARD)
	check(fx.particles.size() <= fx.MAX_PARTICLES and fx.flashes.size() <= 4, "Particle and flash counts are bounded")
	fx.tick(3)
	check(fx.particles.is_empty() and fx.flashes.is_empty(), "Expired effects are released")
	fx.queue_free()
	model.queue_free()
	await process_frame
	print("PRESENTATION RESULT: ", failed, " failures")
	quit(0 if failed == 0 else 1)
