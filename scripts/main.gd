extends Node3D

const Field = preload("res://scripts/battlefield.gd")
const Tank = preload("res://scripts/tank.gd")
const Visual = preload("res://scripts/tank_visual.gd")
const Combat = preload("res://scripts/combat_math.gd")
const Effects = preload("res://scripts/battle_effects.gd")
const Hud = preload("res://scripts/hud.gd")
var field: Node3D
var tank: CharacterBody3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var hud: Control
var playing := false
var started := false
var scoped := false
var yaw := 0.0
var pitch := -0.075
var zoom := 10.5
var cooldown := 0.0
var reload_time := 2.3
var shells: Array[Dictionary] = []
var fx: Node3D
var shot_kick := 0.0
var aim_point := Vector3.ZERO
var muzzle_hit := Vector3.ZERO
var blocked := false
var hit_flash := 0.0
var destroyed := 0
var shots := 0
var hits := 0
var message := "TRAINING RANGE / 06 TARGETS"
var audio: AudioStreamPlayer

func _ready() -> void:
	setup_environment()
	fx = Effects.new()
	add_child(fx)
	field = Field.new()
	add_child(field)
	tank = Tank.new()
	add_child(tank)
	tank.spawn_point = Vector3(0, Field.height(0, 43) + 0.5, 43)
	tank.reset()
	pivot = Node3D.new()
	add_child(pivot)
	pivot.position = tank.position + Vector3(0, 3.7, 0)
	arm = SpringArm3D.new()
	arm.spring_length = zoom
	arm.margin = 0.35
	arm.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	arm.shape = sphere
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 65
	camera.near = 0.08
	camera.far = 550
	arm.add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	set_playing(false)

func setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("263d50")
	sky_mat.sky_horizon_color = Color("8a9c9d")
	sky_mat.ground_bottom_color = Color("464b3b")
	sky_mat.ground_horizon_color = Color("b7bda9")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("859fad")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("798e94")
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.2
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe1a6")
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-29, 138, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("8aaac4")
	fill.light_energy = 0.32
	fill.rotation_degrees = Vector3(-45, -42, 0)
	add_child(fill)

func set_playing(value: bool) -> void:
	playing = value
	if value:
		started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	tank.set_physics_process(value)
	tank.throttle = 0
	tank.steering = 0
	scoped = false
	if is_instance_valid(hud):
		hud.update_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and playing:
		set_playing(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			set_playing(not playing)
		elif event.physical_keycode == KEY_R and playing:
			get_tree().reload_current_scene()
	if not playing:
		return
	if event is InputEventMouseMotion:
		var sensitivity := 0.0010 if scoped else 0.0025
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -0.65, 0.3)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.7, 5.5, 16)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.7, 5.5, 16)

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _physics_process(dt: float) -> void:
	if not playing:
		pivot.rotation = Vector3(pitch, yaw, 0)
		return
	scoped = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	tank.throttle = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	tank.steering = float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
	tank.brake = Input.is_physical_key_pressed(KEY_SPACE)
	pivot.position = pivot.position.lerp(tank.position + Vector3(0, 2.8 if scoped else 3.7, 0), 1 - exp(-10 * dt))
	pivot.rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = 0.0 if scoped else zoom
	shot_kick *= exp(-12 * dt)
	camera.rotation.x = shot_kick
	camera.fov = lerpf(camera.fov, 29 if scoped else 65, 1 - exp(-12 * dt))
	tank.model.visible = not scoped
	var center := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var direction := camera.project_ray_normal(center)
	var result := ray(origin, origin + direction * 450)
	aim_point = result.get("position", origin + direction * 450)
	tank.aim_point = aim_point
	# Predict from the barrel, not the camera: reticle represents the real trajectory.
	var muzzle: Vector3 = tank.model.muzzle.global_position
	var velocity: Vector3 = -tank.model.muzzle.global_basis.z * 115
	var breech: Vector3 = tank.model.barrel.global_position
	var obstruct := ray(breech, muzzle)
	blocked = not obstruct.is_empty()
	muzzle_hit = obstruct.get("position", muzzle + velocity * 3)
	if not blocked:
		var pos := muzzle
		for i in range(125):
			var next := Combat.advance(pos, velocity, 0.04)
			var contact := ray(pos, next.position)
			if not contact.is_empty():
				muzzle_hit = contact.position
				break
			pos = next.position
			velocity = next.velocity
			muzzle_hit = pos
	cooldown = maxf(0, cooldown - dt)
	hit_flash = maxf(0, hit_flash - dt)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and cooldown <= 0:
		fire()
	update_shells(dt)
	fx.drive(tank.model, tank.speed, tank.steering, dt)
	fx.tick(dt)
	hud.queue_redraw()

func fire() -> void:
	if cooldown > 0:
		return
	cooldown = reload_time
	shots += 1
	var muzzle: Vector3 = tank.model.muzzle.global_position
	var direction: Vector3 = -tank.model.muzzle.global_basis.z
	var obstruction := ray(tank.model.barrel.global_position, muzzle)
	play_boom()
	fx.fire(muzzle, direction)
	tank.model.kick_recoil()
	shot_kick = 0.014 if scoped else 0.025
	if not obstruction.is_empty():
		impact(obstruction)
		return
	var mesh := Visual.box(self, Vector3(0.065, 0.065, 0.9), muzzle, Visual.material(Color("ffe4a0")))
	mesh.look_at(muzzle + direction)
	shells.append({"node": mesh, "position": muzzle, "velocity": direction * 115, "life": 5.0})

func update_shells(dt: float) -> void:
	for i in range(shells.size() - 1, -1, -1):
		var shell := shells[i]
		var next := Combat.advance(shell.position, shell.velocity, dt)
		var contact := ray(shell.position, next.position)
		shell.life -= dt
		if not contact.is_empty() or shell.life <= 0:
			if not contact.is_empty():
				impact(contact)
			shell.node.queue_free()
			shells.remove_at(i)
		else:
			shell.position = next.position
			shell.velocity = next.velocity
			shell.node.position = next.position
			shell.node.look_at(next.position + next.velocity)

func impact(contact: Dictionary) -> void:
	fx.impact(contact.position, contact.get("normal", Vector3.UP))
	var body: Object = contact.collider
	if body.has_meta("target"):
		hits += 1
		hit_flash = 0.4
		var hp := int(body.get_meta("hp")) - 1
		body.set_meta("hp", hp)
		message = "TARGET %02d / HIT" % body.get_meta("index")
		if hp <= 0:
			destroyed += 1
			message = "TARGET %02d / DESTROYED" % body.get_meta("index")
			fx.impact(contact.position, Vector3.UP, true)
			body.queue_free()
			if destroyed == 6:
				message = "RANGE CLEAR / PRESS R TO RESTART"

func play_boom() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var data := PackedByteArray()
	var rate := 22050
	data.resize(rate / 3 * 2)
	for i in range(data.size() / 2):
		var t := float(i) / rate
		var wave := (sin(t * 240 * TAU) * 0.25 + randf_range(-1, 1) * 0.75) * exp(-t * 22)
		data.encode_s16(i * 2, int(wave * 18000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	audio.stream = stream
	audio.volume_db = -13
	audio.play()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
