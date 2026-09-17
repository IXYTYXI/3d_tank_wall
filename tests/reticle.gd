extends SceneTree
var failed := 0
func check(ok: bool, message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok: failed += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_process_input(false)
 game.set_physics_process(false)
 for i in range(3): await physics_frame
 if not game.hud.has_method("gun_reticle_position"):
  check(false,"Primary reticle must project actual gun trajectory instead of fixed center")
 else:
  game.camera.reparent(game)
  game.camera.position = Vector3(0,5,20)
  game.camera.look_at(Vector3(0,2,0))
  game.muzzle_hit = Vector3(-5,2,0)
  var left: Vector2 = game.hud.gun_reticle_position()
  game.muzzle_hit = Vector3(5,2,0)
  var right: Vector2 = game.hud.gun_reticle_position()
  check(right.x>left.x+10,"Primary reticle follows barrel trajectory across screen")
  check(right.distance_to(game.camera.unproject_position(game.muzzle_hit).clamp(Vector2(20,110),game.hud.size-Vector2(20,110)))<0.01,"Primary reticle matches projected impact point")
 game.queue_free()
 await process_frame
 quit(1 if failed else 0)
