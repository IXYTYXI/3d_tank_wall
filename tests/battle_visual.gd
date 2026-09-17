extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_unhandled_input(false)
	for i in range(10):
		await process_frame
	await capture("res://outputs/defense-menu.png")
	game.start_defense()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.set_physics_process(false)
	game.battle.tick(6)
	for enemy in game.battle.enemies:
		enemy.set_physics_process(false)
		enemy.position = Vector3(0,load("res://scripts/battlefield.gd").height(0,15)+0.15,15)
	for i in range(60):
		await physics_frame
	game._physics_process(0.016)
	game.hud.queue_redraw()
	await capture("res://outputs/defense-battle.png")
	game.battle.phase = "upgrade"
	game.set_playing(false)
	await capture("res://outputs/defense-upgrade.png")
	game.battle.phase = "combat"
	game.battle.wave = 5
	game.battle.kills = 18
	game.battle.score = 1800
	game.battle.finish(true,"全部敌军已被击退，基地守住了")
	await capture("res://outputs/defense-result.png")
	game.queue_free()
	await process_frame
	quit()
