extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.set_physics_process(false)
	game.tank.set_physics_process(true)
	for i in range(70):
		await physics_frame
	game.tank.set_physics_process(false)
	game.hud.visible = false
	game.camera.reparent(game)
	game.camera.fov = 49
	game.camera.position = game.tank.position+Vector3(6.0,3.4,-8.4)
	game.camera.look_at(game.tank.position+Vector3(0,1.45,-0.4))
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/tank-detail.png")
	game.cooldown = 0
	game.fire()
	game.fx.tick(0.025)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/tank-firing.png")
	for i in range(20):
		game.update_shells(1.0/60)
		game.fx.tick(1.0/60)
		game.tank.model.animate(3,1.0/60)
		game.fx.drive(game.tank.model,3,0,1.0/60)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/tank-smoke.png")
	game.queue_free()
	await process_frame
	quit()
