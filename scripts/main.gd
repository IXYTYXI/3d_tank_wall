extends Node3D

const Field = preload("res://scripts/battlefield.gd")
const Tank = preload("res://scripts/tank.gd")
const Visual = preload("res://scripts/tank_visual.gd")
const Combat = preload("res://scripts/combat_math.gd")
const Effects = preload("res://scripts/battle_effects.gd")
const Battle = preload("res://scripts/battle_director.gd")
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
var message := "训练场 / 共 6 个靶标"
var audio: AudioStreamPlayer
var battle: Node3D

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
	battle = Battle.new()
	battle.game = self
	add_child(battle)
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
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/battle_sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("859fad")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("71858b")
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.2
	# Optional cinematic renderer; the default remains compatible with older GPUs.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 0.7
		env.ssao_enabled = true
		env.ssao_radius = 1.8
		env.ssao_intensity = 2.0
		env.ssao_light_affect = 0.35
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0015
		env.volumetric_fog_albedo = Color("718995")
		env.volumetric_fog_sky_affect = 0.25
		env.volumetric_fog_length = 180.0
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe1a6")
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-24, 138, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("8aaac4")
	fill.light_energy = 0.12
	fill.rotation_degrees = Vector3(-45, -42, 0)
	add_child(fill)

func set_playing(value: bool) -> void:
	if value and is_instance_valid(battle) and (battle.finished() or battle.phase == "upgrade"):
		return
	playing = value
	if value:
		started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	tank.set_physics_process(value and not tank.dead)
	if is_instance_valid(battle):
		for enemy in battle.enemies:
			enemy.set_physics_process(value and not enemy.dead)
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
		elif event.physical_keycode == KEY_E and playing:
			battle.use_repair()
		elif event.physical_keycode == KEY_R and started:
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

func ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 7)
	query.exclude = exclude if not exclude.is_empty() else [tank.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _physics_process(dt: float) -> void:
	if not playing:
		pivot.rotation = Vector3(pitch, yaw, 0)
		return
	scoped = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	tank.throttle = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	tank.steering = float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
	tank.brake = Input.is_physical_key_pressed(KEY_SHIFT)
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
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE)) and cooldown <= 0:
		fire()
	update_shells(dt)
	fx.drive(tank.model, tank.speed, tank.steering, dt)
	fx.tick(dt)
	battle.tick(dt)
	hud.queue_redraw()

func start_defense() -> void:
	start_mode("defense")

func start_mode(mode: String) -> void:
	if battle.finished():
		get_tree().reload_current_scene()
		return
	if not started:
		battle.start(mode)
	set_playing(true)

func fire() -> void:
	if cooldown > 0 or tank.dead or battle.finished():
		return
	cooldown = reload_time*(0.65 if battle.fast_reload_time>0 else 1.0)
	shots += 1
	play_boom()
	shot_kick = 0.014 if scoped else 0.025
	fire_actor(tank,48.0)

func fire_actor(actor: CharacterBody3D, damage: float) -> void:
	if actor.dead:
		return
	var muzzle: Vector3 = actor.model.muzzle.global_position
	var direction: Vector3 = -actor.model.muzzle.global_basis.z
	var obstruction := ray(actor.model.barrel.global_position,muzzle,[actor.get_rid()])
	fx.fire(muzzle,direction)
	actor.model.kick_recoil()
	if not obstruction.is_empty():
		impact(obstruction,actor.faction,damage,direction)
		return
	var color := Color("ffe4a0") if actor.faction==0 else Color("ff9871")
	var mesh := Visual.box(self,Vector3(0.065,0.065,0.9),muzzle,Visual.material(color))
	mesh.look_at(muzzle+direction)
	shells.append({"node":mesh,"position":muzzle,"velocity":direction*115,"life":5.0,
		"owner":actor.get_rid(),"faction":actor.faction,"damage":damage})

func update_shells(dt: float) -> void:
	for i in range(shells.size() - 1, -1, -1):
		var shell := shells[i]
		var next := Combat.advance(shell.position, shell.velocity, dt)
		var contact := ray(shell.position,next.position,[shell.owner])
		shell.life -= dt
		if not contact.is_empty() or shell.life <= 0:
			if not contact.is_empty():
				impact(contact,shell.faction,shell.damage,shell.velocity)
			shell.node.queue_free()
			shells.remove_at(i)
		else:
			shell.position = next.position
			shell.velocity = next.velocity
			shell.node.position = next.position
			shell.node.look_at(next.position + next.velocity)

func impact(contact: Dictionary, source_faction: int = 0, damage: float = 48.0, travel: Vector3 = Vector3.FORWARD) -> void:
	fx.impact(contact.position, contact.get("normal", Vector3.UP))
	var body: Object = contact.collider
	if body.has_method("take_damage"):
		if body.faction != source_faction:
			var applied: int = body.take_damage(damage,travel)
			if applied>0 and source_faction==0:
				hits += 1
				hit_flash = 0.4
				if not body.dead:
					message = "命中敌军 / 伤害 %d" % applied
		return
	if body.has_meta("base"):
		if source_faction != 0:
			battle.damage_base(damage)
		return
	if body.has_meta("target"):
		hits += 1
		hit_flash = 0.4
		var hp := int(body.get_meta("hp")) - 1
		body.set_meta("hp", hp)
		message = "靶标 %02d / 命中" % body.get_meta("index")
		if hp <= 0:
			destroyed += 1
			message = "靶标 %02d / 已摧毁" % body.get_meta("index")
			fx.impact(contact.position, Vector3.UP, true)
			body.queue_free()
			if destroyed == 6:
				message = "训练完成 / 按 R 重新开始"

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
