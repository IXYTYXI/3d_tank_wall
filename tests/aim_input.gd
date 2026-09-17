extends SceneTree
var failures := 0
var game: Node3D
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures += 1
func motion(delta: Vector2) -> void:
	# Only the injected event should control this deterministic test; ignore the
	# real desktop cursor and capture-warp events between test steps.
	Input.flush_buffered_events()
	game.set_process_input(true)
	game.set_process_unhandled_input(true)
	var event := InputEventMouseMotion.new()
	event.position = root.size*0.5
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_move_to_foreground()
	# Let window activation and mouse-capture notifications settle first.
	for i in range(60): await physics_frame
	game.set_playing(true)
	motion(Vector2(100,0))
	check(is_equal_approx(game.yaw,-0.25),"Captured aiming uses screen pixels independent of viewport stretch")
	# A foreground Control must not swallow captured gameplay look events.
	var overlay := Control.new()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	for i in range(2): await process_frame
	var before: float = game.yaw
	motion(Vector2(100,0))
	check(game.yaw<before-0.2,"Captured mouse motion reaches aim before GUI interception")
	var hull: float = game.tank.rotation.y
	for i in range(90): await physics_frame
	print("AIM STATE playing=",game.playing," yaw=",game.yaw," turret=",game.tank.model.turret.rotation.y," target=",game.tank.aim_point," focused=",DisplayServer.window_is_focused())
	check(absf(game.tank.model.turret.rotation.y)>0.2,"Mouse input turns physical turret toward camera target")
	check(is_equal_approx(game.tank.rotation.y,hull),"Mouse aim does not rotate hull")
	game.set_playing(false)
	before = game.yaw
	motion(Vector2(100,0))
	check(is_equal_approx(game.yaw,before),"Pause menu mouse motion does not turn turret")
	game.set_playing(true)
	before = game.yaw
	motion(Vector2(-100,0))
	check(game.yaw>before+0.2,"Resuming restores mouse aim")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.playing,"Focus loss pauses control")
	before = game.yaw
	motion(Vector2(100,0))
	check(is_equal_approx(game.yaw,before),"Unfocused mouse motion cannot change aim")
	overlay.queue_free()
	game.queue_free()
	await process_frame
	print("AIM INPUT RESULT: ",failures," failures")
	quit(1 if failures else 0)
