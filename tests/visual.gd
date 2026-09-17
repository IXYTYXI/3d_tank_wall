extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/menu.png")
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.set_playing(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.yaw = -0.32
	game.pitch = -0.10
	for i in range(60):
		await physics_frame
	game.set_physics_process(false)
	await RenderingServer.frame_post_draw
	var path := "res://outputs/first-playable.png"
	root.get_texture().get_image().save_png(path)
	print("Screenshot saved: ", path)
	print("Camera ", game.camera.global_position, " tank ", game.tank.global_position)
	game.queue_free()
	await process_frame
	quit()
