extends SceneTree
var failed := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:
		failed += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	for kind in ["rock","barrier","dragon_tooth","hedgehog","pine"]:
		var body: StaticBody3D = game.field.add_asset(kind,Vector3.ZERO,Vector3.ONE,0,0)
		body.position = Vector3(0,20,0)
		for i in range(3):
			await physics_frame
		var y := 0.0 if kind=="rock" else 1.12 if kind=="hedgehog" else 0.7
		var hit: Dictionary = game.ray(Vector3(0,20+y,-4),Vector3(0,20+y,4))
		check(hit.get("collider")==body,kind+" stops actual combat rays at its solid surface")
		if kind=="hedgehog":
			check(body.get_children().filter(func(node): return node is CollisionShape3D).size()==3,"Hedgehog uses three beam colliders instead of a solid cube")
		body.queue_free()
		await physics_frame
	game.start_defense()
	game.set_physics_process(false)
	game.tank.set_physics_process(false)
	await physics_frame
	var base: Vector3 = game.battle.base.position
	var sandbag: Dictionary = game.ray(base+Vector3(3.55,-1.1,-6),base+Vector3(3.55,-1.1,-3))
	check(sandbag.get("collider")==game.battle.base,"Command-post sandbag frontage blocks shells")
	check(game.battle.navigation.path(Vector3(0,0,43),Vector3(0,0,-40)).size()>1,"Added obstacles preserve a traversable battlefield")
	game.queue_free()
	await process_frame
	quit(0 if failed==0 else 1)
