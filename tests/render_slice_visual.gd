extends SceneTree
var game: Node3D

func _initialize() -> void:
	call_deferred("capture")

func shot(file: String, eye: Vector3, target: Vector3, fov: float) -> void:
	game.camera.position = eye
	game.camera.look_at(target)
	game.camera.fov = fov
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/"+file+".png")

func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.set_physics_process(false)
	game.tank.set_physics_process(true)
	for i in range(70):
		await physics_frame
	game.tank.set_physics_process(false)
	game.hud.hide()
	game.camera.reparent(game)
	var position: Vector3 = game.tank.position
	await shot("render-slice-detail",position+Vector3(6,3.4,-8.4),position+Vector3(0,1.45,-0.4),49)
	await shot("render-slice-wide",position+Vector3(7,2.3,-10),position+Vector3(0,2.7,0),57)
	# The ordinary driving camera remains readable with its HUD and distant targets.
	game.hud.show()
	game.set_playing(true)
	game.set_physics_process(false)
	game.tank.set_physics_process(false)
	await shot("render-slice-driving",position+Vector3(0,4.7,10),position+Vector3(0,1.8,-30),65)
	var timings: Array[float] = []
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in range(60):
		await process_frame
	for i in range(240):
		var start := Time.get_ticks_usec()
		game.camera.position.x = position.x+sin(i*0.015)*4
		game.camera.look_at(position+Vector3(0,1.8,-30))
		await process_frame
		timings.append((Time.get_ticks_usec()-start)/1000.0)
	timings.sort()
	var total := 0.0
	for value in timings:
		total += value
	print("RENDER SAMPLE: frames=240 resolution=",root.size," average_fps=",240000.0/total," p95_frame_ms=",timings[227]," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("Static training scene; no combat load. Not a minimum FPS guarantee.")
	game.queue_free()
	await process_frame
	quit()
