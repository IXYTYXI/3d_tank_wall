extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/update-menu.png")
	game.hud.updater.checked.connect(func(message: String,_url: String): print("LIVE UPDATE: ",message))
	game.hud.update_button.pressed.emit()
	await game.hud.updater.checked
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://outputs/update-result.png")
	game.queue_free()
	await process_frame
	quit()
