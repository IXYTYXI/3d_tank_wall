extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.start_defense()
	var moved := 0.0
	var maximum_shots := 0
	var last_positions := {}
	for frame in range(3600):
		await physics_frame
		var total_shots := 0
		for ai in game.battle.controllers:
			total_shots += ai.shots_fired
			var id: int = ai.actor.get_instance_id()
			if last_positions.has(id):
				moved += ai.actor.position.distance_to(last_positions[id])
			last_positions[id] = ai.actor.position
		maximum_shots = maxi(maximum_shots,total_shots)
		if frame%600==0:
			print("AI SIM t=",frame/60," phase=",game.battle.phase," enemies=",game.battle.enemies.size()," shots=",total_shots," hp=",game.tank.health," base=",game.battle.base_health)
		if game.battle.finished():
			break
	var movement_ok: bool = moved>20
	var firing_ok: bool = maximum_shots>0
	var damage_ok: bool = game.tank.health<game.tank.max_health or game.battle.base_health<360
	print("PASS " if movement_ok else "FAIL ","AI navigates across terrain: ",moved)
	print("PASS " if firing_ok else "FAIL ","AI aligns and fires real shells: ",maximum_shots)
	print("PASS " if damage_ok else "FAIL ","AI shells can damage a defended target")
	for ai in game.battle.controllers:
		print("AI end position=",ai.actor.position," path=",ai.route.size()," waypoint=",ai.route_index)
	game.queue_free()
	await process_frame
	quit(0 if movement_ok and firing_ok and damage_ok else 1)
