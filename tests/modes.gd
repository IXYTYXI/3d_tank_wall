extends SceneTree
var failures := 0
var game: Node3D
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func session(mode: String) -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.start_mode(mode)
	game.set_physics_process(false)
	game.tank.set_physics_process(false)
	await physics_frame
func dispose() -> void:
	game.queue_free()
	await process_frame
func clear_enemies() -> void:
	for enemy in game.battle.enemies.duplicate():
		enemy.take_damage(9999,Vector3.FORWARD)
	await physics_frame
func run() -> void:
	var script = load("res://scripts/main.gd")
	var probe = script.new()
	var supported: bool = probe.has_method("start_mode")
	probe.free()
	check(supported,"Game exposes additional combat modes")
	if not supported:
		quit(1)
		return
	await session("survival")
	var battle: Node3D = game.battle
	check(battle.mode=="survival" and not is_instance_valid(battle.base),"Survival has no defendable base")
	battle.tick(6)
	check(battle.phase=="combat" and battle.enemies.size()==1,"Survival starts an enemy wave")
	battle.tick(0.1)
	check(battle.controllers[0].actor.aim_point.is_finite(),"Survival enemy can aim without a base")
	battle.pending = 0
	battle.wave = 5
	await clear_enemies()
	battle.tick(0.1)
	check(battle.phase=="upgrade","Survival continues after wave five")
	battle.apply_upgrade("armor")
	battle.tick(8)
	check(battle.wave==6 and battle.remaining()==8,"Survival wave six increases enemy count")
	battle.pending = 0
	await clear_enemies()
	battle.tick(0.1)
	battle.wave = 40
	battle.apply_upgrade("reload")
	battle.tick(8)
	check(battle.remaining()==12,"Endless wave size stays bounded")
	check(absf(battle.enemies[0].position.z)<112,"Late survival spawns stay inside battlefield")
	game.tank.take_damage(9999,Vector3.FORWARD)
	check(battle.phase=="lost","Survival ends on player destruction")
	await dispose()
	await session("elimination")
	battle = game.battle
	check(not is_instance_valid(battle.base) and battle.time_left==180,"Elimination starts with 180 seconds and no base")
	battle.tick(5)
	check(battle.phase=="combat" and battle.time_left==180,"Initial preparation does not consume mission time")
	game.set_playing(false)
	game._physics_process(10)
	check(battle.time_left==180,"Pause freezes elimination timer")
	game.set_playing(true)
	battle.tick(1)
	check(battle.time_left==179,"Active mission consumes time")
	while battle.kills<12 and not battle.finished():
		await clear_enemies()
		if not battle.finished():
			battle.tick(3)
	check(battle.phase=="won" and battle.kills==12,"Twelve eliminations win without upgrade interruption")
	game.set_playing(true)
	check(not game.playing,"Elimination result cannot resume")
	await dispose()
	await session("elimination")
	game.battle.tick(5)
	game.battle.tick(180)
	check(game.battle.phase=="lost" and game.battle.time_left==0,"Mission timeout loses at zero")
	await dispose()
	await session("defense")
	check(is_instance_valid(game.battle.base) and game.battle.mode=="defense","Default defense retains its base")
	await dispose()
	print("MODES RESULT: ",failures," failures")
	quit(0 if failures==0 else 1)
