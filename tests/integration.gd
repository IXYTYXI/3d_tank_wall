extends SceneTree

var failures := 0
var game: Node3D

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	check(game.hud.title.global_position.y >= 0, "Menu title is inside the viewport")
	game.set_physics_process(false)
	game.tank.set_physics_process(true)
	await frames(90)
	check(game.tank.is_on_floor(), "Tank settles on terrain")
	check(game.tank.position.y > -5, "Tank does not fall through terrain")
	var ground: Dictionary = game.ray(Vector3(0, 20, 43), Vector3(0, -20, 43))
	check(not ground.is_empty() and ground.normal.y > 0.8, "Terrain ray returns upward ground normal")
	var start: Vector3 = game.tank.position
	game.tank.throttle = 1
	await frames(90)
	check(game.tank.position.z < start.z - 3, "Forward input drives along ground")
	game.tank.throttle = 0
	game.tank.brake = true
	await frames(60)
	check(absf(game.tank.speed) < 0.1, "Brake stops tank")
	game.tank.brake = false
	game.tank.throttle = -1
	start = game.tank.position
	await frames(90)
	check(game.tank.position.z > start.z + 2, "Reverse input drives backward")
	game.tank.throttle = 0
	var hull_yaw: float = game.tank.rotation.y
	game.tank.aim_point = game.tank.position + Vector3(40, 4, -15)
	await frames(100)
	check(absf(game.tank.rotation.y - hull_yaw) < 0.001, "Aiming leaves hull yaw unchanged")
	check(absf(game.tank.model.turret.rotation.y) > 0.5, "Turret rotates independently toward target")
	game.tank.set_physics_process(false)
	game.tank.position = Vector3(0, 10, 0)
	game.tank.rotation = Vector3.ZERO
	game.tank.model.basis = Basis.IDENTITY
	game.tank.model.turret.rotation = Vector3.ZERO
	game.tank.model.barrel.rotation = Vector3.ZERO
	var muzzle: Vector3 = game.tank.model.muzzle.global_position
	var wall: StaticBody3D = game.field.block(Vector3(5, 5, 0.08), muzzle + Vector3(0, 0, -3), game.tank.model.armor)
	await frames(3)
	game.fire()
	check(game.shells.size() == 1, "One shell spawned at actual muzzle")
	if game.shells.size() == 1:
		check(game.shells[0].position.distance_to(muzzle) < 0.001, "Shell origin equals actual muzzle marker")
	var shots_before: int = game.shots
	game.fire()
	check(game.shots == shots_before, "Reload prevents repeated firing")
	game.update_shells(0.1)
	check(game.shells.is_empty(), "Fast shell cannot tunnel through thin wall")
	wall.queue_free()
	await frames(3)
	var breech: Vector3 = game.tank.model.barrel.global_position
	wall = game.field.block(Vector3(3, 3, 0.2), breech.lerp(muzzle, 0.5), game.tank.model.armor)
	await frames(3)
	game.cooldown = 0
	game.fire()
	check(game.shells.is_empty(), "Obstructed barrel impacts cover before spawning shell")
	wall.queue_free()
	await frames(3)
	game.pivot.position = Vector3(0, 15, 0)
	game.pivot.rotation = Vector3.ZERO
	game.arm.spring_length = 10
	wall = game.field.block(Vector3(8, 8, 0.4), Vector3(0, 15, 4), game.tank.model.armor)
	await frames(5)
	check(game.arm.get_hit_length() < 4, "Spring arm retracts before rear wall")
	wall.queue_free()
	await frames(5)
	check(game.arm.get_hit_length() > 9, "Spring arm restores after obstruction removed")
	game.playing = true
	var scope_event := InputEventMouseButton.new()
	scope_event.button_index = MOUSE_BUTTON_RIGHT
	scope_event.pressed = true
	Input.parse_input_event(scope_event)
	Input.flush_buffered_events()
	game._physics_process(0.1)
	check(game.scoped and game.camera.fov < 65, "Scope narrows field of view")
	check(not game.tank.model.visible, "Scope hides local tank to prevent model clipping")
	scope_event = scope_event.duplicate()
	scope_event.pressed = false
	Input.parse_input_event(scope_event)
	Input.flush_buffered_events()
	game._physics_process(0.1)
	check(not game.scoped and game.tank.model.visible, "Leaving scope restores third person model")
	var target: StaticBody3D = game.field.targets[0]
	game.impact({"position": target.global_position, "collider": target})
	check(target.get_meta("hp") == 1 and game.hits == 1, "First target hit records damage and feedback")
	game.impact({"position": target.global_position, "collider": target})
	check(game.destroyed == 1 and target.is_queued_for_deletion(), "Second target hit destroys the target")
	game.set_playing(false)
	check(not game.tank.is_physics_processing(), "Pause suspends tank motion")
	game.queue_free()
	await frames(2)
	print("INTEGRATION RESULT: ", failures, " failures")
	quit(0 if failures == 0 else 1)
