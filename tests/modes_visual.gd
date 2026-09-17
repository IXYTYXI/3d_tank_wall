extends SceneTree
var game: Node3D
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in range(count):
		await process_frame
func shot(name: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://outputs")
	for mode in ["survival","elimination"]:
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process_unhandled_input(false)
		await frames(10)
		if mode=="survival":
			await shot("modes-menu")
		game.start_mode(mode)
		game.set_physics_process(false)
		game.tank.set_physics_process(false)
		game.battle.tick(6)
		game.battle.enemies[0].set_physics_process(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		game.hud.queue_redraw()
		await shot(mode+"-battle")
		game.battle.finish(mode=="elimination","模式界面检查")
		await shot(mode+"-result")
		game.queue_free()
		await frames(3)
	quit()
