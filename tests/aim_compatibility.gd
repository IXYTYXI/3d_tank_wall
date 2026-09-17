extends SceneTree
var failures := 0
var game: Node3D
func check(ok: bool, message: String) -> void:
 print('PASS ' if ok else 'FAIL ',message)
 if not ok: failures += 1
func key(code: int, pressed: bool) -> void:
 var event := InputEventKey.new()
 event.physical_keycode=code
 event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func motion(relative: Vector2, screen: Vector2) -> void:
 Input.flush_buffered_events()
 game.set_process_input(true)
 var event := InputEventMouseMotion.new()
 event.position=root.size*0.5
 event.relative=relative
 event.screen_relative=screen
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 game.set_process_input(false)
func frames(count: int) -> void:
 for i in range(count): await physics_frame
func _initialize() -> void: call_deferred('run')
func run() -> void:
 game=load('res://scenes/main.tscn').instantiate()
 root.add_child(game)
 game.set_process_input(false)
 game.set_process_unhandled_input(false)
 if DisplayServer.get_name()!='headless': DisplayServer.window_move_to_foreground()
 await frames(60)
 game.set_playing(true)
 var hull: float=game.tank.rotation.y
 motion(Vector2(120,0),Vector2.ZERO)
 check(is_equal_approx(game.yaw,-0.3),'Legacy relative-only mouse movement turns aim, without screen_relative')
 await frames(75)
 check(game.tank.model.turret.rotation.y < -0.2,'Relative-only input rotates actual turret mesh')
 check(is_equal_approx(game.tank.rotation.y,hull),'Mouse rotation leaves hull independent')
 var before: float=game.yaw
 motion(Vector2.ZERO,Vector2(80,0))
 check(is_equal_approx(game.yaw,before-0.2),'Screen-only movement remains supported')
 before=game.yaw
 motion(Vector2.ZERO,Vector2.ZERO)
 check(is_equal_approx(game.yaw,before),'Zero-motion event cannot turn the camera')
 key(KEY_LEFT,true)
 await frames(75)
 key(KEY_LEFT,false)
 check(game.yaw > before+0.7,'Left arrow turns aiming independently without mouse events')
 check(game.tank.model.turret.rotation.y > 0.1,'Keyboard rotates actual turret, not just the reticle')
 check(is_equal_approx(game.tank.rotation.y,hull),'Keyboard aim does not steer hull')
 # Drive and aim together through the live main loop.
 key(KEY_A,true)
 key(KEY_RIGHT,true)
 before=game.yaw
 await frames(100)
 key(KEY_A,false)
 key(KEY_RIGHT,false)
 check(game.tank.rotation.y > hull+0.8,'A turns hull during simultaneous keyboard aiming')
 check(game.yaw < before-0.8,'Right arrow aims opposite to A steering')
 print('SIMULTANEOUS hull=',game.tank.rotation_degrees.y,' turret_local=',game.tank.model.turret.rotation_degrees.y)
 check(absf(game.tank.model.turret.rotation.y)>deg_to_rad(20),'Turret separates from hull while driving')
 before=game.pitch
 key(KEY_UP,true)
 await frames(15)
 key(KEY_UP,false)
 check(game.pitch > before+0.05,'Up arrow raises aiming')
 game.set_playing(false)
 before=game.yaw
 key(KEY_LEFT,true)
 await frames(15)
 key(KEY_LEFT,false)
 check(is_equal_approx(game.yaw,before),'Pause blocks keyboard aim')
 game.set_playing(true)
 before=game.yaw
 key(KEY_RIGHT,true)
 await frames(15)
 key(KEY_RIGHT,false)
 check(game.yaw < before-0.05,'Resume restores keyboard aim')
 print('FINAL ANGLES hull=',game.tank.rotation_degrees.y,' turret_local=',game.tank.model.turret.rotation_degrees.y,' aim=',rad_to_deg(game.yaw))
 game.queue_free()
 await process_frame
 print('AIM COMPATIBILITY RESULT: ',failures,' failures')
 quit(1 if failures else 0)
