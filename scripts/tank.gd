extends CharacterBody3D

const Visual = preload("res://scripts/tank_visual.gd")
const Combat = preload("res://scripts/combat_math.gd")
var model: Node3D
var speed := 0.0
var throttle := 0.0
var steering := 0.0
var brake := false
var aim_point := Vector3(0, 2, -100)
var spawn_point := Vector3.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.85
	floor_max_angle = deg_to_rad(43)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.7, 1.6, 4.8)
	shape.shape = box
	shape.position.y = 0.95
	add_child(shape)
	model = Visual.new()
	add_child(model)

func _physics_process(dt: float) -> void:
	var target_speed := throttle * (13.5 if throttle > 0 else 6.0)
	speed = move_toward(speed, target_speed, (18.0 if brake else 4.0 if throttle else 5.0) * dt)
	if brake:
		speed = move_toward(speed, 0, 18 * dt)
	rotate_y(steering * dt * (0.65 + minf(absf(speed) / 13.5, 1.0) * 0.2))
	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y -= 20.0 * dt
	move_and_slide()
	if get_real_velocity().length() < absf(speed) * 0.25 and absf(speed) > 2:
		speed = move_toward(speed, 0, 20 * dt)
	if is_on_floor():
		var normal := global_basis.inverse() * get_floor_normal()
		var desired := Basis.looking_at(Vector3.FORWARD.slide(normal).normalized(), normal)
		model.basis = model.basis.slerp(desired, minf(dt * 6, 1)).orthonormalized()
	model.animate(speed, dt)
	var local_target: Vector3 = model.to_local(aim_point) - model.turret.position
	var yaw := atan2(-local_target.x, -local_target.z)
	model.turret.rotation.y = rotate_toward(model.turret.rotation.y, yaw, dt * 0.9)
	var barrel_local: Vector3 = model.turret.global_basis.inverse() * (aim_point - model.barrel.global_position)
	model.barrel.rotation.x = move_toward(model.barrel.rotation.x, Combat.elevation(barrel_local), dt * 0.5)
	if position.y < -35:
		reset()

func reset() -> void:
	position = spawn_point
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	speed = 0
	model.basis = Basis.IDENTITY
	model.turret.rotation = Vector3.ZERO
	model.barrel.rotation = Vector3.ZERO
