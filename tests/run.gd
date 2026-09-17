extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	if not ResourceLoader.exists("res://scripts/combat_math.gd"):
		check(false, "Combat math is missing: projectile gravity and barrel limits are not implemented")
		quit(1)
		return
	var math = load("res://scripts/combat_math.gd")
	var step: Dictionary = math.advance(Vector3.ZERO, Vector3(0, 0, -100), 0.1)
	check(is_equal_approx(step.position.z, -10.0), "Shell travels from its own position at muzzle velocity")
	check(step.position.y < 0.0, "Gravity lowers the shell")
	check(is_equal_approx(step.velocity.y, -0.981), "Gravity integrates velocity")
	check(is_equal_approx(math.elevation(Vector3(0, 100, -1)), deg_to_rad(22)), "Elevation limited to 22 degrees")
	check(is_equal_approx(math.elevation(Vector3(0, -100, -1)), deg_to_rad(-9)), "Depression limited to -9 degrees")
	check(is_zero_approx(math.elevation(Vector3(0, 0, -100))), "Level shot stays level")
	print("Combat checks: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
