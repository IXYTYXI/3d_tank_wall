extends SceneTree
var game: Node3D
const Field = preload("res://scripts/battlefield.gd")
func _initialize() -> void:
	call_deferred("capture")
func shot(name: String, eye: Vector3, target: Vector3, fov: float = 49) -> void:
	game.camera.position = eye
	game.camera.look_at(target)
	game.camera.fov = fov
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/"+name+".png")
	print(name," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.start_defense()
	game.set_physics_process(false)
	game.tank.set_physics_process(true)
	for i in range(70):
		await physics_frame
	game.tank.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud.hide()
	game.camera.reparent(game)
	await shot("world-driving",game.tank.position+Vector3(0,4.7,10),game.tank.position+Vector3(0,1.8,-30),62)
	var base: Vector3 = Vector3(0,Field.height(0,65),65)
	await shot("command-post",base+Vector3(8,5.7,-12),base+Vector3(0,2.8,-0.7),53)
	var front := Vector3(-24,Field.height(-24,-8),-8)
	await shot("defense-obstacles",front+Vector3(10,5.5,9),front+Vector3(0,0.9,0),53)
	var tree: StaticBody3D
	for body in game.field.get_children():
		if body is StaticBody3D and body.get_meta("asset_kind","")=="pine" and body.position.x>30 and body.position.z>0:
			tree = body
			break
	await shot("forest-detail",tree.position+Vector3(10,5,11),tree.position+Vector3(0,4,0),55)
	var hedge: StaticBody3D
	for body in game.field.get_children():
		if body is StaticBody3D and body.get_meta("asset_kind","")=="hedgehog":
			hedge = body
			break
	await shot("hedgehog-detail",hedge.position+Vector3(4,2.8,4),hedge.position+Vector3(0,1,0),50)
	for i in range(3):
		var enemy = load("res://scripts/tank.gd").new()
		enemy.faction = 1
		enemy.variant = ["轻型坦克","标准坦克","重型坦克"][i]
		game.add_child(enemy)
		enemy.position = Vector3(-7+i*7,Field.height(-7+i*7,-94)+0.16,-94)
		enemy.set_physics_process(false)
		enemy.model.animate(4,0.18)
	await shot("enemy-lineup",Vector3(14,Field.height(0,-94)+7,-108),Vector3(0,Field.height(0,-94)+1.4,-94),55)
	# Four fully animated enemies in a representative gameplay view.
	var fourth = load("res://scripts/tank.gd").new()
	fourth.faction = 1
	game.add_child(fourth)
	fourth.position = Vector3(14,Field.height(14,-94)+0.16,-94)
	fourth.set_physics_process(false)
	var started := Time.get_ticks_usec()
	for frame in range(180):
		for child in game.get_children():
			if child is CharacterBody3D and child.faction==1:
				child.model.animate(4,1.0/60)
		await process_frame
	print("Four-enemy renderer: ",180.0/((Time.get_ticks_usec()-started)/1000000.0)," average frames/s (uncapped scene capture)")
	game.queue_free()
	await process_frame
	quit()
